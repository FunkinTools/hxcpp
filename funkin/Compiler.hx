package funkin;

import sys.FileSystem;
import sys.io.File;
import haxe.Exception;

using StringTools;

class Compiler
{
   static final BUILD_XML:String          = "Build.xml";
   static final TOOLCHAIN_DIR:String      = "toolchain";
   static final OUTPUT_DIR:String         = "export";
   static final HAXELIB_JSON:String       = "haxelib.json";

   static final ENV_NDK:String            = "ANDROID_NDK_ROOT";
   static final ENV_SDK:String            = "ANDROID_HOME";
   static final ENV_JAVA:String           = "JAVA_HOME";

   static final MIN_SDK:Int               = 21;
   static final TARGET_SDK:Int            = 34;

   static final ANDROID_ABIS:Array<String> = ["arm64-v8a", "armeabi-v7a", "x86_64"];
   static final IOS_ARCHS:Array<String>    = ["arm64", "arm64e"];
   static final DESKTOP_ARCHS:Array<String> = ["x86_64"];

   public static function main():Void
   {
      final args   = Sys.args();
      final target = resolveTarget(args);

      if (args.contains("--help") || args.contains("-h"))
      {
         printUsage();
         return;
      }

      final config = resolveConfig(args, target);

      validateEnvironment(config);

      switch target
      {
         case Platform.Windows:  buildWindows(config);
         case Platform.Linux:    buildLinux(config);
         case Platform.Mac:      buildMac(config);
         case Platform.Android:  buildAndroid(config);
         case Platform.iOS:      buildIOS(config);
         case Platform.HTML5:    buildHTML5(config);
         case Platform.All:      buildAll(config);
      }
   }

   static function resolveTarget(args:Array<String>):Platform
   {
      return switch resolveArg(args, "--target", "all").toLowerCase()
      {
         case "windows":  Platform.Windows;
         case "linux":    Platform.Linux;
         case "mac":      Platform.Mac;
         case "android":  Platform.Android;
         case "ios":      Platform.iOS;
         case "html5":    Platform.HTML5;
         case "all":      Platform.All;
         case other:      throw new Exception('Unknown target: $other');
      }
   }

   static function resolveConfig(args:Array<String>, target:Platform):CompilerConfig
   {
      return {
         target:      target,
         debug:       args.contains("--debug"),
         strip:       args.contains("--strip"),
         verbose:     args.contains("--verbose"),
         outputDir:   resolveArg(args, "--output",     OUTPUT_DIR),
         ndkRoot:     resolveArg(args, "--ndk",        Sys.getEnv(ENV_NDK)),
         sdkRoot:     resolveArg(args, "--sdk",        Sys.getEnv(ENV_SDK)),
         javaHome:    resolveArg(args, "--java",       Sys.getEnv(ENV_JAVA)),
         abis:        resolveArgList(args, "--abi",    ANDROID_ABIS),
         iosArchs:    resolveArgList(args, "--arch",   IOS_ARCHS),
         minSdk:      resolveArgInt(args, "--min-sdk", MIN_SDK),
         targetSdk:   resolveArgInt(args, "--target-sdk", TARGET_SDK),
         extraFlags:  resolveExtraFlags(args)
      };
   }

   static function validateEnvironment(config:CompilerConfig):Void
   {
      if (!FileSystem.exists(BUILD_XML))
         throw new Exception('$BUILD_XML not found in current directory.');

      ensureDir(config.outputDir);

      switch config.target
      {
         case Platform.Android | Platform.All:
            if (config.ndkRoot == null || !FileSystem.exists(config.ndkRoot))
               throw new Exception('Android NDK not found. Set $ENV_NDK or pass --ndk <path>.');
            if (config.sdkRoot == null || !FileSystem.exists(config.sdkRoot))
               throw new Exception('Android SDK not found. Set $ENV_SDK or pass --sdk <path>.');
            if (config.javaHome == null || !FileSystem.exists(config.javaHome))
               throw new Exception('Java home not found. Set $ENV_JAVA or pass --java <path>.');
         case _:
      }
   }

   static function buildWindows(config:CompilerConfig):Void
   {
      Sys.println("Building for Windows...");

      final flags = baseFlags(config).concat([
         "-DWINDOWS",
         "-DWINDOWS64",
         "-DHXCPP_M64"
      ]);

      if (!config.debug)
         flags.push("-DOPTIMIZE");

      runBuild(config, "Windows64", flags);
   }

   static function buildLinux(config:CompilerConfig):Void
   {
      Sys.println("Building for Linux...");

      final flags = baseFlags(config).concat([
         "-DLINUX",
         "-DHXCPP_M64"
      ]);

      runBuild(config, "Linux64", flags);
   }

   static function buildMac(config:CompilerConfig):Void
   {
      Sys.println("Building for macOS...");

      final flags = baseFlags(config).concat([
         "-DMACOS",
         "-DHXCPP_M64",
         "-DAPPLE"
      ]);

      runBuild(config, "Mac64", flags);
   }

   static function buildAndroid(config:CompilerConfig):Void
   {
      Sys.println("Building for Android...");

      ensureDir('${config.outputDir}/android');

      for (abi in config.abis)
      {
         Sys.println('  ABI: $abi');

         final abiOut = '${config.outputDir}/android/$abi';
         ensureDir(abiOut);

         final flags = baseFlags(config).concat([
            "-DANDROID",
            '-DANDROID_NDK=${config.ndkRoot}',
            '-DANDROID_SDK=${config.sdkRoot}',
            '-DANDROID_ABI=$abi',
            '-DANDROID_MIN_SDK=${config.minSdk}',
            '-DANDROID_TARGET_SDK=${config.targetSdk}',
            '-DOUTPUT=$abiOut'
         ]);

         if (abi == "armeabi-v7a")
            flags.push("-DHXCPP_ARMV7");
         else if (abi == "arm64-v8a")
            flags.push("-DHXCPP_ARM64");
         else if (abi == "x86_64")
            flags.push("-DHXCPP_M64");

         runBuildRaw(config, flags);
         Sys.println('  ABI $abi — OK');
      }
   }

   static function buildIOS(config:CompilerConfig):Void
   {
      Sys.println("Building for iOS...");

      ensureDir('${config.outputDir}/ios');

      for (arch in config.iosArchs)
      {
         Sys.println('  Arch: $arch');

         final archOut = '${config.outputDir}/ios/$arch';
         ensureDir(archOut);

         final flags = baseFlags(config).concat([
            "-DIPHONEOS",
            "-DAPPLE",
            '-DIOS_ARCH=$arch',
            '-DOUTPUT=$archOut'
         ]);

         if (arch == "arm64" || arch == "arm64e")
            flags.push("-DHXCPP_ARM64");

         runBuildRaw(config, flags);
         Sys.println('  Arch $arch — OK');
      }
   }

   static function buildHTML5(config:CompilerConfig):Void
   {
      Sys.println("Building for HTML5...");

      final flags = baseFlags(config).concat([
         "-DEMSCRIPTEN",
         "-DHTML5"
      ]);

      if (!config.debug)
      {
         flags.push("-O2");
         flags.push("-DOPTIMIZE");
      }

      runBuild(config, "html5", flags);
   }

   static function buildAll(config:CompilerConfig):Void
   {
      Sys.println("Building for all platforms...");

      final host = Sys.systemName().toLowerCase();

      if (host.indexOf("window") >= 0)
         buildWindows(config);
      else if (host.indexOf("mac") >= 0)
         buildMac(config);
      else
         buildLinux(config);

      buildAndroid(config);
   }

   static function runBuild(config:CompilerConfig, platform:String, flags:Array<String>):Void
   {
      final outDir = '${config.outputDir}/$platform';
      ensureDir(outDir);
      runBuildRaw(config, flags.concat(['-DOUTPUT=$outDir']));
   }

   static function runBuildRaw(config:CompilerConfig, flags:Array<String>):Void
   {
      final allFlags = [BUILD_XML].concat(flags).concat(config.extraFlags);

      if (config.verbose)
         Sys.println("neko run.n " + allFlags.join(" "));

      final exitCode = Sys.command("neko", ["run.n"].concat(allFlags));

      if (exitCode != 0)
         throw new Exception('Build failed (exit code: $exitCode)');
   }

   static function baseFlags(config:CompilerConfig):Array<String>
   {
      final flags:Array<String> = [];

      if (config.debug)
      {
         flags.push("-DDEBUG");
         flags.push("-DHXCPP_DEBUG_LINK");
      }
      else
      {
         flags.push("-DRELEASE");
         flags.push("-DHXCPP_OPTIMIZE_FOR_SIZE");
      }

      if (config.strip)
         flags.push("-DSTRIP");

      return flags;
   }

   static function resolveArg(args:Array<String>, flag:String, fallback:String):String
   {
      final idx = args.indexOf(flag);
      if (idx >= 0 && idx + 1 < args.length)
         return args[idx + 1];
      return fallback;
   }

   static function resolveArgInt(args:Array<String>, flag:String, fallback:Int):Int
   {
      final val = resolveArg(args, flag, null);
      if (val == null) return fallback;
      final parsed = Std.parseInt(val);
      return parsed != null ? parsed : fallback;
   }

   static function resolveArgList(args:Array<String>, flag:String, fallback:Array<String>):Array<String>
   {
      final val = resolveArg(args, flag, null);
      if (val == null) return fallback;
      return val.split(",").map(s -> s.trim()).filter(s -> s.length > 0);
   }

   static function resolveExtraFlags(args:Array<String>):Array<String>
   {
      return args.filter(a -> a.startsWith("-D") && !a.startsWith("-DHXCPP"));
   }

   static function ensureDir(path:String):Void
   {
      if (!FileSystem.exists(path))
         FileSystem.createDirectory(path);
   }

   static function printUsage():Void
   {
      Sys.println("Usage: haxe Compiler.hxml [options]");
      Sys.println("");
      Sys.println("Targets:");
      Sys.println("  --target windows       Build for Windows x64");
      Sys.println("  --target linux         Build for Linux x64");
      Sys.println("  --target mac           Build for macOS x64");
      Sys.println("  --target android       Build for Android");
      Sys.println("  --target ios           Build for iOS");
      Sys.println("  --target html5         Build for HTML5 (Emscripten)");
      Sys.println("  --target all           Build for all platforms (default)");
      Sys.println("");
      Sys.println("Options:");
      Sys.println("  --output    <path>     Output directory (default: export)");
      Sys.println("  --ndk       <path>     Android NDK root");
      Sys.println("  --sdk       <path>     Android SDK root");
      Sys.println("  --java      <path>     Java home");
      Sys.println("  --abi       <list>     Android ABIs, comma-separated");
      Sys.println("  --arch      <list>     iOS archs, comma-separated");
      Sys.println("  --min-sdk   <int>      Android minimum SDK (default: 21)");
      Sys.println("  --target-sdk <int>     Android target SDK (default: 34)");
      Sys.println("  --debug                Debug build");
      Sys.println("  --strip                Strip symbols");
      Sys.println("  --verbose              Print build commands");
      Sys.println("  --help                 Show this help");
   }
}

enum Platform
{
   Windows;
   Linux;
   Mac;
   Android;
   iOS;
   HTML5;
   All;
}

typedef CompilerConfig = {
   var target:Platform;
   var debug:Bool;
   var strip:Bool;
   var verbose:Bool;
   var outputDir:String;
   var ndkRoot:Null<String>;
   var sdkRoot:Null<String>;
   var javaHome:Null<String>;
   var abis:Array<String>;
   var iosArchs:Array<String>;
   var minSdk:Int;
   var targetSdk:Int;
   var extraFlags:Array<String>;
}
