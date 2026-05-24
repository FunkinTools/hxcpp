package funkin.hxcpp;

import sys.FileSystem;
import sys.io.File;
import haxe.Exception;

using StringTools;

class Android
{
   static final NDK_VERSION:String        = "25.1.8937393";
   static final MIN_SDK_VERSION:Int       = 21;
   static final TARGET_SDK_VERSION:Int    = 34;
   static final DEFAULT_ABI:Array<String> = ["arm64-v8a", "armeabi-v7a", "x86_64"];

   static final TOOLCHAIN_DIR:String      = "toolchain";
   static final TOOLCHAIN_FILE:String     = "android-toolchain.xml";
   static final BUILD_XML:String          = "Build.xml";
   static final HAXELIB_JSON:String       = "haxelib.json";

   static final ENV_ANDROID_NDK:String    = "ANDROID_NDK_ROOT";
   static final ENV_ANDROID_SDK:String    = "ANDROID_HOME";
   static final ENV_JAVA_HOME:String      = "JAVA_HOME";

   public static function main():Void
   {
      final args = Sys.args();

      if (args.contains("--help") || args.contains("-h"))
      {
         printUsage();
         return;
      }

      final config = resolveConfig(args);

      validateEnvironment(config);
      generateToolchain(config);
      build(config);
   }

   static function resolveConfig(args:Array<String>):AndroidConfig
   {
      final ndkRoot  = resolveArg(args, "--ndk",    Sys.getEnv(ENV_ANDROID_NDK));
      final sdkRoot  = resolveArg(args, "--sdk",    Sys.getEnv(ENV_ANDROID_SDK));
      final javaHome = resolveArg(args, "--java",   Sys.getEnv(ENV_JAVA_HOME));
      final abis     = resolveArgList(args, "--abi", DEFAULT_ABI);
      final minSdk   = resolveArgInt(args, "--min-sdk",    MIN_SDK_VERSION);
      final targetSdk= resolveArgInt(args, "--target-sdk", TARGET_SDK_VERSION);
      final debug    = args.contains("--debug");
      final strip    = args.contains("--strip");
      final output   = resolveArg(args, "--output", "export/android");

      return {
         ndkRoot:       ndkRoot,
         sdkRoot:       sdkRoot,
         javaHome:      javaHome,
         abis:          abis,
         minSdk:        minSdk,
         targetSdk:     targetSdk,
         debug:         debug,
         strip:         strip,
         outputDir:     output
      };
   }

   static function validateEnvironment(config:AndroidConfig):Void
   {
      if (config.ndkRoot == null || !FileSystem.exists(config.ndkRoot))
         throw new Exception('Android NDK not found. Set $ENV_ANDROID_NDK or pass --ndk <path>.');

      if (config.sdkRoot == null || !FileSystem.exists(config.sdkRoot))
         throw new Exception('Android SDK not found. Set $ENV_ANDROID_SDK or pass --sdk <path>.');

      if (config.javaHome == null || !FileSystem.exists(config.javaHome))
         throw new Exception('Java home not found. Set $ENV_JAVA_HOME or pass --java <path>.');

      final ndkVersion = resolveNdkVersion(config.ndkRoot);
      if (ndkVersion == null)
         throw new Exception('Could not determine NDK version from: ${config.ndkRoot}');

      Sys.println('NDK version detected: $ndkVersion');

      for (abi in config.abis)
         if (!isSupportedAbi(abi))
            throw new Exception('Unsupported ABI: $abi. Supported: ${DEFAULT_ABI.join(", ")}');

      if (!FileSystem.exists(config.outputDir))
         FileSystem.createDirectory(config.outputDir);
   }

   static function generateToolchain(config:AndroidConfig):Void
   {
      final toolchainPath = '$TOOLCHAIN_DIR/$TOOLCHAIN_FILE';

      final clangPrefix   = resolveClangPrefix(config.ndkRoot, config.abis[0]);
      final sysroot       = '${config.ndkRoot}/toolchains/llvm/prebuilt/${resolveHostTag()}/sysroot';

      final lines:Array<String> = [
         '<toolchain>',
         '',
         '   <set name="ANDROID_NDK"       value="${config.ndkRoot}" />',
         '   <set name="ANDROID_SDK"       value="${config.sdkRoot}" />',
         '   <set name="ANDROID_MIN_SDK"   value="${config.minSdk}" />',
         '   <set name="ANDROID_TARGET_SDK" value="${config.targetSdk}" />',
         '',
         '   <set name="CLANG_PREFIX"      value="$clangPrefix" />',
         '   <set name="SYSROOT"           value="$sysroot" />',
         '',
         '   <compiler id="android-clang" exe="${config.ndkRoot}/toolchains/llvm/prebuilt/${resolveHostTag()}/bin/clang++">',
         '      <flag value="-target ${resolveClangTarget(config.abis[0], config.minSdk)}" />',
         '      <flag value="-fPIC" />',
         '      <flag value="-ffunction-sections" />',
         '      <flag value="-fdata-sections" />',
         '      <flag value="-funwind-tables" />',
         '      <flag value="-fstack-protector-strong" />',
         '      <flag value="-no-canonical-prefixes" />',
         (config.debug
            ? '      <flag value="-g" />'
            : '      <flag value="-O2" />'),
         '      <flag value="--sysroot=$sysroot" />',
         '   </compiler>',
         '',
         '   <linker id="android-linker" exe="${config.ndkRoot}/toolchains/llvm/prebuilt/${resolveHostTag()}/bin/clang++">',
         '      <flag value="-target ${resolveClangTarget(config.abis[0], config.minSdk)}" />',
         '      <flag value="-Wl,--gc-sections" />',
         '      <flag value="-Wl,--warn-shared-textrel" />',
         (config.strip
            ? '      <flag value="-Wl,--strip-all" />'
            : ''),
         '      <lib name="log" />',
         '      <lib name="android" />',
         '      <lib name="dl" />',
         '      <lib name="z" />',
         '   </linker>',
         '',
         '</toolchain>'
      ];

      if (!FileSystem.exists(TOOLCHAIN_DIR))
         FileSystem.createDirectory(TOOLCHAIN_DIR);

      File.saveContent(toolchainPath, lines.filter(l -> l != null).join("\n"));
      Sys.println('Toolchain written to: $toolchainPath');
   }

   static function build(config:AndroidConfig):Void
   {
      final baseFlags:Array<String> = [
         BUILD_XML,
         '-DANDROID',
         '-DANDROID_NDK=${config.ndkRoot}',
         '-DANDROID_MIN_SDK=${config.minSdk}',
         '-DANDROID_TARGET_SDK=${config.targetSdk}',
         '-DOUTPUT=${config.outputDir}'
      ];

      if (config.debug)
         baseFlags.push("-DDEBUG");

      for (abi in config.abis)
      {
         Sys.println('Building ABI: $abi');

         final abiFlags = baseFlags.concat([
            '-DANDROID_ABI=$abi',
            '-DABI_OUTPUT=${config.outputDir}/$abi'
         ]);

         if (!FileSystem.exists('${config.outputDir}/$abi'))
            FileSystem.createDirectory('${config.outputDir}/$abi');

         final exitCode = Sys.command("neko", ["run.n"].concat(abiFlags));

         if (exitCode != 0)
            throw new Exception('Build failed for ABI $abi (exit code: $exitCode)');

         Sys.println('ABI $abi — OK');
      }

      Sys.println('Android build complete. Output: ${config.outputDir}');
   }

   static function resolveNdkVersion(ndkRoot:String):Null<String>
   {
      final sourceProps = '$ndkRoot/source.properties';
      if (!FileSystem.exists(sourceProps))
         return null;

      for (line in File.getContent(sourceProps).split("\n"))
      {
         if (line.startsWith("Pkg.Revision"))
         {
            final parts = line.split("=");
            if (parts.length == 2)
               return parts[1].trim();
         }
      }
      return null;
   }

   static function resolveHostTag():String
   {
      final os = Sys.systemName().toLowerCase();
      if (os.indexOf("window") >= 0) return "windows-x86_64";
      if (os.indexOf("mac")    >= 0) return "darwin-x86_64";
      return "linux-x86_64";
   }

   static function resolveClangPrefix(ndkRoot:String, abi:String):String
   {
      return switch abi
      {
         case "arm64-v8a":   "aarch64-linux-android";
         case "armeabi-v7a": "arm-linux-androideabi";
         case "x86":         "i686-linux-android";
         case "x86_64":      "x86_64-linux-android";
         case _: throw new Exception('No clang prefix for ABI: $abi');
      }
   }

   static function resolveClangTarget(abi:String, minSdk:Int):String
   {
      return switch abi
      {
         case "arm64-v8a":   'aarch64-linux-android$minSdk';
         case "armeabi-v7a": 'armv7a-linux-androideabi$minSdk';
         case "x86":         'i686-linux-android$minSdk';
         case "x86_64":      'x86_64-linux-android$minSdk';
         case _: throw new Exception('No clang target for ABI: $abi');
      }
   }

   static function isSupportedAbi(abi:String):Bool
   {
      return ["arm64-v8a", "armeabi-v7a", "x86", "x86_64"].contains(abi);
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

   static function printUsage():Void
   {
      Sys.println("Usage: haxe android.hxml [options]");
      Sys.println("");
      Sys.println("Options:");
      Sys.println("  --ndk       <path>       Path to Android NDK root");
      Sys.println("  --sdk       <path>       Path to Android SDK root");
      Sys.println("  --java      <path>       Path to Java home");
      Sys.println("  --abi       <list>       Comma-separated ABIs (default: arm64-v8a,armeabi-v7a,x86_64)");
      Sys.println("  --min-sdk   <int>        Minimum SDK version (default: 21)");
      Sys.println("  --target-sdk <int>       Target SDK version (default: 34)");
      Sys.println("  --output    <path>       Output directory (default: export/android)");
      Sys.println("  --debug                  Enable debug build");
      Sys.println("  --strip                  Strip symbols from output");
      Sys.println("  --help                   Show this help");
   }
}

typedef AndroidConfig = {
   var ndkRoot:Null<String>;
   var sdkRoot:Null<String>;
   var javaHome:Null<String>;
   var abis:Array<String>;
   var minSdk:Int;
   var targetSdk:Int;
   var debug:Bool;
   var strip:Bool;
   var outputDir:String;
}
