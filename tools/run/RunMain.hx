import sys.FileSystem;

class RunMain
{
   static final ENV_NON_INTERACTIVE:String = "HXCPP_NONINTERACTIVE";
   static final TIMEOUT_SECONDS:Float      = 30.0;
   static final HXCPP_MODULE:String        = "./hxcpp.n";

   static final PLATFORM_WINDOWS:String    = "Windows64";
   static final PLATFORM_MAC:String        = "Mac64";
   static final PLATFORM_LINUX:String      = "Linux64";

   static final TOOLS_DIR:String           = "tools/hxcpp";
   static final COMPILE_HXML:String        = "compile.hxml";

   public static function log(message:String):Void
      Sys.println(message);

   public static function main():Void
   {
      if (!executeHxcpp())
         showMessage();
   }

   public static function setup():Void
   {
      log("Compiling hxcpp tool...");
      run(TOOLS_DIR, "haxe", [COMPILE_HXML]);
      log("Initial setup complete.");
   }

   public static function run(dir:String, command:String, args:Array<String>):Int
   {
      var previousDir:String = "";

      if (dir != "")
      {
         previousDir = Sys.getCwd();
         Sys.setCwd(dir);
      }

      final exitCode:Int = Sys.command(command, args);

      if (previousDir != "")
         Sys.setCwd(previousDir);

      return exitCode;
   }

   public static function executeHxcpp():Bool
   {
      if (!FileSystem.exists(HXCPP_MODULE))
         return false;

      if (!Sys.args().contains("-DHXCPP_NEKO_BUILDTOOL=1"))
      {
         final nativeBinary = resolveNativeBinary();

         if (nativeBinary != null)
         {
            if (!FileSystem.exists(nativeBinary))
            {
               log('Native binary not found at $nativeBinary, falling back to neko.');
            }
            else if (isBinaryOutOfDate(nativeBinary))
            {
               final fullPath = Sys.getCwd() + nativeBinary;
               log('Warning: $fullPath is out of date. Please delete or rebuild.');
            }
            else
            {
               Sys.exit(Sys.command(nativeBinary, Sys.args()));
               return true;
            }
         }
      }

      neko.vm.Loader.local().loadModule(HXCPP_MODULE);
      return true;
   }

   static function resolveNativeBinary():Null<String>
   {
      final os         = Sys.systemName().toLowerCase();
      final isWindows  = os.indexOf("window") >= 0;
      final isMac      = os.indexOf("mac")    >= 0;
      final isLinux    = os.indexOf("linux")  >= 0;

      final platform   = isWindows ? PLATFORM_WINDOWS
                       : isMac     ? PLATFORM_MAC
                       : isLinux   ? PLATFORM_LINUX
                       : null;

      if (platform == null)
         return null;

      final executable = isWindows ? "BuildTool.exe" : "BuildTool";
      return 'bin/$platform/$executable';
   }

   static function isBinaryOutOfDate(binaryPath:String):Bool
   {
      final moduleTime = FileSystem.stat(HXCPP_MODULE).mtime.getTime();
      final binaryTime = FileSystem.stat(binaryPath).mtime.getTime();
      return binaryTime < moduleTime;
   }

   static function isNonInteractive():Bool
   {
      if (Sys.getEnv(ENV_NON_INTERACTIVE) != null)
         return true;

      final flag = "-D" + ENV_NON_INTERACTIVE;
      for (arg in Sys.args())
         if (arg.indexOf(flag) == 0)
            return true;

      return false;
   }

   public static function showMessage():Void
   {
      final cwd = Sys.getCwd();

      if (isNonInteractive())
      {
         log('HXCPP in $cwd is missing hxcpp.n');
         Sys.exit(-1);
         return;
      }

      printSetupInstructions(cwd);

      if (!promptUser())
      {
         log("\nCan't continue without hxcpp.n");
         Sys.exit(-1);
      }
   }

   static function printSetupInstructions(cwd:String):Void
   {
      log('This version of hxcpp ($cwd) appears to be a source/development version.');
      log("Before this can be used, you need to:");
      log("  1. Rebuild the main command-line tool:");
      log("       cd tools/hxcpp");
      log("       haxe compile.hxml");
      log("  2. FOR HXCPP API < 330 — build the binaries for your system:");
      log("       cd project");
      log("       neko build.n");
   }

   static function promptUser():Bool
   {
      var gotResponse:Bool = false;

      sys.thread.Thread.create(() ->
      {
         Sys.sleep(TIMEOUT_SECONDS);
         if (!gotResponse)
         {
            log("\nTimeout waiting for response.");
            log("Can't continue without hxcpp.n");
            Sys.exit(-1);
         }
      });

      while (true)
      {
         Sys.print("\nWould you like to do this now? [y/n] ");

         final code:Int = Sys.getChar(true);
         gotResponse = true;

         if (code <= 32)
            break;

         final answer:String = String.fromCharCode(code);

         if (answer == "y" || answer == "Y")
         {
            log("");
            setup();
            return executeHxcpp();
         }

         if (answer == "n" || answer == "N")
            break;
      }

      return false;
   }
}
