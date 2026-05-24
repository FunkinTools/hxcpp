package funkin.helpers;

import sys.FileSystem;
import sys.io.File;
import haxe.Exception;

using StringTools;

class Warning
{
   static final HAXELIB_JSON:String     = "haxelib.json";
   static final BUILD_XML:String        = "Build.xml";
   static final PROJECT_XML:String      = "project.xml";
   static final TOOLCHAIN_DIR:String    = "toolchain";
   static final EXPORT_DIR:String       = "export";

   static final MIN_HAXE_MAJOR:Int      = 4;
   static final MIN_HAXE_MINOR:Int      = 3;
   static final MIN_NEKO_MAJOR:Int      = 2;
   static final MIN_NEKO_MINOR:Int      = 3;
   static final RECOMMENDED_NDK:String  = "25.1.8937393";

   static var warnings:Array<WarningEntry> = [];
   static var errors:Array<WarningEntry>   = [];

   public static function main():Void
   {
      final args   = Sys.args();
      final silent = args.contains("--silent");
      final strict = args.contains("--strict");
      final target = resolveArg(args, "--target", "all");

      run(target, silent, strict);
   }

   public static function run(target:String, silent:Bool, strict:Bool):Void
   {
      warnings = [];
      errors   = [];

      checkHaxeVersion();
      checkNekoVersion();
      checkProjectFiles();
      checkToolchainDir();
      checkExportDir();
      checkHaxelibJson();

      if (target == "android" || target == "all")
         checkAndroid();

      if (target == "ios" || target == "all")
         checkIOS();

      if (target == "windows" || target == "all")
         checkWindows();

      if (target == "linux" || target == "all")
         checkLinux();

      if (target == "mac" || target == "all")
         checkMac();

      report(silent, strict);
   }

   static function checkHaxeVersion():Void
   {
      final raw = runCapture("haxe", ["--version"]);

      if (raw == null)
      {
         addError(Category.Environment, "Haxe is not installed or not in PATH.");
         return;
      }

      final version = parseVersion(raw.trim());
      if (version == null)
      {
         addWarning(Category.Environment, 'Could not parse Haxe version: "$raw"');
         return;
      }

      if (version.major < MIN_HAXE_MAJOR
      || (version.major == MIN_HAXE_MAJOR && version.minor < MIN_HAXE_MINOR))
      {
         addWarning(Category.Environment,
            'Haxe ${version.major}.${version.minor}.${version.patch} is below the recommended '
          + '$MIN_HAXE_MAJOR.$MIN_HAXE_MINOR.x. Some features may not compile correctly.'
         );
      }
   }

   static function checkNekoVersion():Void
   {
      final raw = runCapture("neko", ["-version"]);

      if (raw == null)
      {
         addError(Category.Environment, "Neko is not installed or not in PATH.");
         return;
      }

      final version = parseVersion(raw.trim());
      if (version == null)
      {
         addWarning(Category.Environment, 'Could not parse Neko version: "$raw"');
         return;
      }

      if (version.major < MIN_NEKO_MAJOR
      || (version.major == MIN_NEKO_MAJOR && version.minor < MIN_NEKO_MINOR))
      {
         addWarning(Category.Environment,
            'Neko ${version.major}.${version.minor}.${version.patch} is below the recommended '
          + '$MIN_NEKO_MAJOR.$MIN_NEKO_MINOR.x.'
         );
      }
   }

   static function checkProjectFiles():Void
   {
      if (!FileSystem.exists(BUILD_XML))
         addWarning(Category.Project, '$BUILD_XML not found in current directory.');

      if (!FileSystem.exists(PROJECT_XML) && !FileSystem.exists("Project.xml"))
         addWarning(Category.Project, 'No project.xml or Project.xml found.');

      if (!FileSystem.exists(HAXELIB_JSON))
         addWarning(Category.Project, '$HAXELIB_JSON not found.');
   }

   static function checkToolchainDir():Void
   {
      if (!FileSystem.exists(TOOLCHAIN_DIR))
         addWarning(Category.Project,
            'Toolchain directory "$TOOLCHAIN_DIR" not found. '
          + 'Custom platform builds may fail.'
         );
   }

   static function checkExportDir():Void
   {
      if (FileSystem.exists(EXPORT_DIR))
      {
         final stat = FileSystem.stat(EXPORT_DIR);
         if (stat == null)
            addWarning(Category.Project, 'Could not stat export directory.');
      }
   }

   static function checkHaxelibJson():Void
   {
      if (!FileSystem.exists(HAXELIB_JSON))
         return;

      try
      {
         final content = File.getContent(HAXELIB_JSON);
         final json    = haxe.Json.parse(content);

         if (json.version == null)
            addWarning(Category.Project, '$HAXELIB_JSON is missing the "version" field.');

         if (json.name == null)
            addWarning(Category.Project, '$HAXELIB_JSON is missing the "name" field.');

         if (json.contributors == null || (json.contributors:Array<Dynamic>).length == 0)
            addWarning(Category.Project, '$HAXELIB_JSON has no contributors listed.');
      }
      catch (e:Exception)
      {
         addError(Category.Project, '$HAXELIB_JSON is not valid JSON: ${e.message}');
      }
   }

   static function checkAndroid():Void
   {
      final ndkRoot  = Sys.getEnv("ANDROID_NDK_ROOT");
      final sdkRoot  = Sys.getEnv("ANDROID_HOME");
      final javaHome = Sys.getEnv("JAVA_HOME");

      if (ndkRoot == null)
         addWarning(Category.Android, "ANDROID_NDK_ROOT is not set.");
      else if (!FileSystem.exists(ndkRoot))
         addError(Category.Android, 'ANDROID_NDK_ROOT points to a non-existent path: "$ndkRoot"');
      else
      {
         final ndkVersion = readNdkVersion(ndkRoot);
         if (ndkVersion == null)
            addWarning(Category.Android, 'Could not read NDK version from: "$ndkRoot"');
         else if (ndkVersion != RECOMMENDED_NDK)
            addWarning(Category.Android,
               'NDK version $ndkVersion detected. Recommended: $RECOMMENDED_NDK. '
             + 'Compatibility issues may occur.'
            );
      }

      if (sdkRoot == null)
         addWarning(Category.Android, "ANDROID_HOME is not set.");
      else if (!FileSystem.exists(sdkRoot))
         addError(Category.Android, 'ANDROID_HOME points to a non-existent path: "$sdkRoot"');

      if (javaHome == null)
         addWarning(Category.Android, "JAVA_HOME is not set.");
      else if (!FileSystem.exists(javaHome))
         addError(Category.Android, 'JAVA_HOME points to a non-existent path: "$javaHome"');
      else
         checkJavaVersion(javaHome);
   }

   static function checkJavaVersion(javaHome:String):Void
   {
      final javaBin = '$javaHome/bin/java';
      final raw     = runCapture(javaBin, ["-version"]);

      if (raw == null)
      {
         addWarning(Category.Android, 'Could not determine Java version from: "$javaBin"');
         return;
      }

      if (!raw.contains("17") && !raw.contains("version \"17"))
         addWarning(Category.Android,
            'Java 17 is recommended for Android builds. Detected: ${raw.split("\n")[0].trim()}'
         );
   }

   static function checkIOS():Void
   {
      final os = Sys.systemName().toLowerCase();

      if (os.indexOf("mac") < 0)
      {
         addWarning(Category.iOS, "iOS builds are only supported on macOS.");
         return;
      }

      final xcode = runCapture("xcode-select", ["-p"]);
      if (xcode == null || xcode.trim().length == 0)
         addError(Category.iOS, "Xcode command-line tools are not installed. Run: xcode-select --install");
   }

   static function checkWindows():Void
   {
      final os = Sys.systemName().toLowerCase();

      if (os.indexOf("window") < 0)
         addWarning(Category.Windows, "Windows builds are intended to run on Windows hosts.");
   }

   static function checkLinux():Void
   {
      final os = Sys.systemName().toLowerCase();

      if (os.indexOf("linux") < 0)
         addWarning(Category.Linux, "Linux builds are intended to run on Linux hosts.");
   }

   static function checkMac():Void
   {
      final os = Sys.systemName().toLowerCase();

      if (os.indexOf("mac") < 0)
         addWarning(Category.Mac, "macOS builds are intended to run on macOS hosts.");
   }

   static function readNdkVersion(ndkRoot:String):Null<String>
   {
      final props = '$ndkRoot/source.properties';
      if (!FileSystem.exists(props))
         return null;

      for (line in File.getContent(props).split("\n"))
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

   static function report(silent:Bool, strict:Bool):Void
   {
      if (silent && errors.length == 0)
         return;

      final totalWarnings = warnings.length;
      final totalErrors   = errors.length;

      if (totalWarnings == 0 && totalErrors == 0)
      {
         Sys.println("[hxcpp] All pre-build checks passed.");
         return;
      }

      Sys.println("");
      Sys.println("=== hxcpp Pre-Build Report ===");

      if (totalErrors > 0)
      {
         Sys.println("");
         Sys.println('ERRORS ($totalErrors):');
         for (entry in errors)
            Sys.println('  [${entry.category}] ${entry.message}');
      }

      if (totalWarnings > 0 && !silent)
      {
         Sys.println("");
         Sys.println('WARNINGS ($totalWarnings):');
         for (entry in warnings)
            Sys.println('  [${entry.category}] ${entry.message}');
      }

      Sys.println("");
      Sys.println('==============================');
      Sys.println('  Errors:   $totalErrors');
      Sys.println('  Warnings: $totalWarnings');
      Sys.println('==============================');
      Sys.println("");

      if (totalErrors > 0 || (strict && totalWarnings > 0))
      {
         Sys.println("Build blocked due to " + (totalErrors > 0 ? "errors" : "warnings in strict mode") + ".");
         Sys.exit(1);
      }
   }

   static function addWarning(category:Category, message:String):Void
   {
      warnings.push({ category: category, message: message });
   }

   static function addError(category:Category, message:String):Void
   {
      errors.push({ category: category, message: message });
   }

   static function runCapture(command:String, args:Array<String>):Null<String>
   {
      try
      {
         final proc   = new sys.io.Process(command, args);
         final stdout = proc.stdout.readAll().toString();
         final stderr = proc.stderr.readAll().toString();
         proc.close();
         final output = stdout.length > 0 ? stdout : stderr;
         return output.length > 0 ? output : null;
      }
      catch (e:Exception)
      {
         return null;
      }
   }

   static function parseVersion(raw:String):Null<SemVer>
   {
      final clean = raw.split(" ")[0].split("-")[0];
      return switch clean.split(".")
      {
         case [major, minor, patch]:
            final ma = Std.parseInt(major);
            final mi = Std.parseInt(minor);
            final pa = Std.parseInt(patch);
            if (ma == null || mi == null || pa == null) null;
            else { major: ma, minor: mi, patch: pa };
         case [major, minor]:
            final ma = Std.parseInt(major);
            final mi = Std.parseInt(minor);
            if (ma == null || mi == null) null;
            else { major: ma, minor: mi, patch: 0 };
         case _:
            null;
      }
   }

   static function resolveArg(args:Array<String>, flag:String, fallback:String):String
   {
      final idx = args.indexOf(flag);
      if (idx >= 0 && idx + 1 < args.length)
         return args[idx + 1];
      return fallback;
   }
}

enum abstract Category(String) to String
{
   var Environment = "Environment";
   var Project     = "Project";
   var Android     = "Android";
   var iOS         = "iOS";
   var Windows     = "Windows";
   var Linux       = "Linux";
   var Mac         = "Mac";
}

typedef SemVer = {
   var major:Int;
   var minor:Int;
   var patch:Int;
}

typedef WarningEntry = {
   var category:Category;
   var message:String;
}
