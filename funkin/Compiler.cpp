#include <hxcpp.h>
#include <hx/CFFI.h>
#include <hx/Macros.h>

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <algorithm>
#include <stdexcept>
#include <sstream>
#include <cstdlib>
#include <cstring>
#include <sys/stat.h>

#ifdef _WIN32
   #include <windows.h>
   #include <process.h>
   #define PATH_SEP "\\"
   #define EXE_EXT  ".exe"
#else
   #include <unistd.h>
   #include <sys/wait.h>
   #include <dirent.h>
   #define PATH_SEP "/"
   #define EXE_EXT  ""
#endif

#ifdef __APPLE__
   #include <TargetConditionals.h>
#endif

#ifdef ANDROID
   #include <android/log.h>
   #define FUNKIN_LOG_TAG "FunkinCompiler"
   #define FUNKIN_LOG(...) __android_log_print(ANDROID_LOG_INFO, FUNKIN_LOG_TAG, __VA_ARGS__)
#else
   #define FUNKIN_LOG(...) do { fprintf(stdout, __VA_ARGS__); fputc('\n', stdout); } while(0)
#endif

namespace funkin
{

enum class Platform
{
   Unknown,
   Windows,
   Linux,
   Mac,
   Android,
   iOS,
   HTML5
};

enum class BuildType
{
   Debug,
   Release,
   RelWithDebInfo
};

enum class Arch
{
   X86,
   X86_64,
   ARM,
   ARM64,
   Unknown
};

struct CompilerFlag
{
   std::string key;
   std::string value;
   bool        isDefine;

   CompilerFlag(const std::string &k, const std::string &v, bool define)
      : key(k), value(v), isDefine(define) {}
};

struct CompilerConfig
{
   Platform              platform      = Platform::Unknown;
   BuildType             buildType     = BuildType::Release;
   Arch                  arch          = Arch::X86_64;
   std::string           outputDir     = "export";
   std::string           ndkRoot;
   std::string           sdkRoot;
   std::string           javaHome;
   std::string           hxcppDir;
   std::vector<std::string> abis       = { "arm64-v8a", "armeabi-v7a", "x86_64" };
   std::vector<std::string> iosArchs   = { "arm64", "arm64e" };
   std::vector<CompilerFlag> extraFlags;
   int                   minSdk        = 21;
   int                   targetSdk     = 34;
   bool                  strip         = false;
   bool                  verbose       = false;
   bool                  strict        = false;
};

static Platform resolvePlatform()
{
   #if defined(_WIN32) || defined(_WIN64)
      return Platform::Windows;
   #elif defined(__APPLE__)
      #if TARGET_OS_IPHONE
         return Platform::iOS;
      #else
         return Platform::Mac;
      #endif
   #elif defined(ANDROID)
      return Platform::Android;
   #elif defined(__EMSCRIPTEN__)
      return Platform::HTML5;
   #elif defined(__linux__)
      return Platform::Linux;
   #else
      return Platform::Unknown;
   #endif
}

static Arch resolveArch()
{
   #if defined(__aarch64__) || defined(_M_ARM64)
      return Arch::ARM64;
   #elif defined(__arm__) || defined(_M_ARM)
      return Arch::ARM;
   #elif defined(__x86_64__) || defined(_M_X64)
      return Arch::X86_64;
   #elif defined(__i386__) || defined(_M_IX86)
      return Arch::X86;
   #else
      return Arch::Unknown;
   #endif
}

static std::string platformToString(Platform p)
{
   switch (p)
   {
      case Platform::Windows: return "Windows";
      case Platform::Linux:   return "Linux";
      case Platform::Mac:     return "Mac";
      case Platform::Android: return "Android";
      case Platform::iOS:     return "iOS";
      case Platform::HTML5:   return "HTML5";
      default:                return "Unknown";
   }
}

static std::string archToString(Arch a)
{
   switch (a)
   {
      case Arch::X86:    return "x86";
      case Arch::X86_64: return "x86_64";
      case Arch::ARM:    return "arm";
      case Arch::ARM64:  return "arm64";
      default:           return "unknown";
   }
}

static bool fileExists(const std::string &path)
{
   struct stat st;
   return stat(path.c_str(), &st) == 0;
}

static bool isFileNewer(const std::string &a, const std::string &b)
{
   struct stat stA, stB;
   if (stat(a.c_str(), &stA) != 0) return false;
   if (stat(b.c_str(), &stB) != 0) return true;
   return stA.st_mtime > stB.st_mtime;
}

static std::string joinPath(const std::string &a, const std::string &b)
{
   if (a.empty()) return b;
   if (b.empty()) return a;
   const char last = a.back();
   if (last == '/' || last == '\\')
      return a + b;
   return a + PATH_SEP + b;
}

static bool makeDir(const std::string &path)
{
   #ifdef _WIN32
      return CreateDirectoryA(path.c_str(), nullptr) || GetLastError() == ERROR_ALREADY_EXISTS;
   #else
      return mkdir(path.c_str(), 0755) == 0 || errno == EEXIST;
   #endif
}

static void ensureDir(const std::string &path)
{
   if (!path.empty() && !fileExists(path))
      makeDir(path);
}

static int runCommand(const std::string &cmd, const std::vector<std::string> &args, bool verbose)
{
   std::string full = cmd;
   for (const auto &arg : args)
      full += " " + arg;

   if (verbose)
      FUNKIN_LOG("Running: %s", full.c_str());

   return std::system(full.c_str());
}

static std::string resolveEnv(const std::string &name, const std::string &fallback = "")
{
   const char *val = std::getenv(name.c_str());
   return val ? std::string(val) : fallback;
}

class Compiler
{
public:
   explicit Compiler(const CompilerConfig &config)
      : mConfig(config)
      , mPlatform(config.platform == Platform::Unknown ? resolvePlatform() : config.platform)
      , mArch(config.arch == Arch::Unknown ? resolveArch() : config.arch)
   {
   }

   bool validate()
   {
      bool ok = true;

      if (mConfig.hxcppDir.empty() || !fileExists(mConfig.hxcppDir))
      {
         FUNKIN_LOG("Error: hxcppDir not set or does not exist.");
         ok = false;
      }

      if (mPlatform == Platform::Android)
      {
         if (mConfig.ndkRoot.empty() || !fileExists(mConfig.ndkRoot))
         {
            FUNKIN_LOG("Error: Android NDK not found. Set ndkRoot or ANDROID_NDK_ROOT.");
            ok = false;
         }
         if (mConfig.sdkRoot.empty() || !fileExists(mConfig.sdkRoot))
         {
            FUNKIN_LOG("Error: Android SDK not found. Set sdkRoot or ANDROID_HOME.");
            ok = false;
         }
         if (mConfig.javaHome.empty() || !fileExists(mConfig.javaHome))
         {
            FUNKIN_LOG("Error: Java home not found. Set javaHome or JAVA_HOME.");
            ok = false;
         }
      }

      if (mPlatform == Platform::iOS)
      {
         #ifndef __APPLE__
            FUNKIN_LOG("Error: iOS builds are only supported on macOS.");
            ok = false;
         #endif
      }

      return ok;
   }

   bool build()
   {
      if (!validate())
         return false;

      ensureDir(mConfig.outputDir);

      switch (mPlatform)
      {
         case Platform::Windows:  return buildDesktop("Windows64",  { "-DWINDOWS", "-DWINDOWS64", "-DHXCPP_M64" });
         case Platform::Linux:    return buildDesktop("Linux64",    { "-DLINUX",   "-DHXCPP_M64" });
         case Platform::Mac:      return buildDesktop("Mac64",      { "-DMACOS",   "-DHXCPP_M64", "-DAPPLE" });
         case Platform::Android:  return buildAndroid();
         case Platform::iOS:      return buildIOS();
         case Platform::HTML5:    return buildHTML5();
         default:
            FUNKIN_LOG("Error: Unknown or unsupported platform.");
            return false;
      }
   }

private:
   CompilerConfig mConfig;
   Platform       mPlatform;
   Arch           mArch;

   std::vector<std::string> baseFlags() const
   {
      std::vector<std::string> flags;

      flags.push_back("Build.xml");

      switch (mConfig.buildType)
      {
         case BuildType::Debug:
            flags.push_back("-DDEBUG");
            flags.push_back("-DHXCPP_DEBUG_LINK");
            break;
         case BuildType::RelWithDebInfo:
            flags.push_back("-DRELEASE");
            flags.push_back("-DHXCPP_OPTIMIZE_FOR_SIZE");
            flags.push_back("-DHXCPP_DEBUG_LINK");
            break;
         default:
            flags.push_back("-DRELEASE");
            flags.push_back("-DHXCPP_OPTIMIZE_FOR_SIZE");
            break;
      }

      if (mConfig.strip)
         flags.push_back("-DSTRIP");

      for (const auto &f : mConfig.extraFlags)
      {
         if (f.isDefine)
            flags.push_back("-D" + f.key + (f.value.empty() ? "" : "=" + f.value));
         else
            flags.push_back(f.key + (f.value.empty() ? "" : "=" + f.value));
      }

      return flags;
   }

   bool runNekoBuild(const std::vector<std::string> &flags) const
   {
      const int result = runCommand("neko", std::vector<std::string>{"run.n"}.also([&](auto &v){
         v.insert(v.end(), flags.begin(), flags.end());
      }), mConfig.verbose);

      if (result != 0)
         FUNKIN_LOG("Build failed with exit code: %d", result);

      return result == 0;
   }

   bool buildDesktop(const std::string &platform, const std::vector<std::string> &platformFlags) const
   {
      FUNKIN_LOG("Building for %s...", platformToString(mPlatform).c_str());

      const std::string outDir = joinPath(mConfig.outputDir, platform);
      ensureDir(outDir);

      auto flags = baseFlags();
      flags.insert(flags.end(), platformFlags.begin(), platformFlags.end());
      flags.push_back("-DOUTPUT=" + outDir);

      return runNekoBuildRaw(flags);
   }

   bool buildAndroid() const
   {
      FUNKIN_LOG("Building for Android...");

      const std::string androidOut = joinPath(mConfig.outputDir, "android");
      ensureDir(androidOut);

      for (const auto &abi : mConfig.abis)
      {
         FUNKIN_LOG("  ABI: %s", abi.c_str());

         const std::string abiOut = joinPath(androidOut, abi);
         ensureDir(abiOut);

         auto flags = baseFlags();
         flags.push_back("-DANDROID");
         flags.push_back("-DANDROID_NDK="      + mConfig.ndkRoot);
         flags.push_back("-DANDROID_SDK="      + mConfig.sdkRoot);
         flags.push_back("-DANDROID_ABI="      + abi);
         flags.push_back("-DANDROID_MIN_SDK="  + std::to_string(mConfig.minSdk));
         flags.push_back("-DANDROID_TARGET_SDK=" + std::to_string(mConfig.targetSdk));
         flags.push_back("-DOUTPUT="           + abiOut);

         if      (abi == "arm64-v8a")   flags.push_back("-DHXCPP_ARM64");
         else if (abi == "armeabi-v7a") flags.push_back("-DHXCPP_ARMV7");
         else if (abi == "x86_64")      flags.push_back("-DHXCPP_M64");
         else if (abi == "x86")         flags.push_back("-DHXCPP_M32");

         if (!runNekoBuildRaw(flags))
         {
            FUNKIN_LOG("  ABI %s — FAILED", abi.c_str());
            return false;
         }

         FUNKIN_LOG("  ABI %s — OK", abi.c_str());
      }

      return true;
   }

   bool buildIOS() const
   {
      FUNKIN_LOG("Building for iOS...");

      const std::string iosOut = joinPath(mConfig.outputDir, "ios");
      ensureDir(iosOut);

      for (const auto &arch : mConfig.iosArchs)
      {
         FUNKIN_LOG("  Arch: %s", arch.c_str());

         const std::string archOut = joinPath(iosOut, arch);
         ensureDir(archOut);

         auto flags = baseFlags();
         flags.push_back("-DIPHONEOS");
         flags.push_back("-DAPPLE");
         flags.push_back("-DIOS_ARCH=" + arch);
         flags.push_back("-DOUTPUT="   + archOut);

         if (arch == "arm64" || arch == "arm64e")
            flags.push_back("-DHXCPP_ARM64");

         if (!runNekoBuildRaw(flags))
         {
            FUNKIN_LOG("  Arch %s — FAILED", arch.c_str());
            return false;
         }

         FUNKIN_LOG("  Arch %s — OK", arch.c_str());
      }

      return true;
   }

   bool buildHTML5() const
   {
      FUNKIN_LOG("Building for HTML5...");

      const std::string outDir = joinPath(mConfig.outputDir, "html5");
      ensureDir(outDir);

      auto flags = baseFlags();
      flags.push_back("-DEMSCRIPTEN");
      flags.push_back("-DHTML5");
      flags.push_back("-DOUTPUT=" + outDir);

      if (mConfig.buildType != BuildType::Debug)
         flags.push_back("-DEMSCRIPTEN_OPTIMIZED");

      return runNekoBuildRaw(flags);
   }

   bool runNekoBuildRaw(const std::vector<std::string> &flags) const
   {
      std::vector<std::string> args = { "run.n" };
      args.insert(args.end(), flags.begin(), flags.end());

      if (mConfig.verbose)
      {
         std::string cmd = "neko";
         for (const auto &a : args) cmd += " " + a;
         FUNKIN_LOG("%s", cmd.c_str());
      }

      const int result = std::system(([&]() {
         std::string cmd = "neko";
         for (const auto &a : args) cmd += " " + a;
         return cmd;
      })().c_str());

      if (result != 0)
         FUNKIN_LOG("Build step failed (exit code: %d)", result);

      return result == 0;
   }
};

}

extern "C"
{

DEFINE_PRIM(void, funkin_compiler_build, vv)
{
   funkin::CompilerConfig config;
   config.platform  = funkin::resolvePlatform();
   config.arch      = funkin::resolveArch();
   config.ndkRoot   = funkin::resolveEnv("ANDROID_NDK_ROOT");
   config.sdkRoot   = funkin::resolveEnv("ANDROID_HOME");
   config.javaHome  = funkin::resolveEnv("JAVA_HOME");
   config.hxcppDir  = funkin::resolveEnv("HXCPP");
   config.outputDir = "export";

   funkin::Compiler compiler(config);
   compiler.build();
}

DEFINE_PRIM(bool, funkin_compiler_validate, vv)
{
   funkin::CompilerConfig config;
   config.platform = funkin::resolvePlatform();
   config.arch     = funkin::resolveArch();
   config.ndkRoot  = funkin::resolveEnv("ANDROID_NDK_ROOT");
   config.sdkRoot  = funkin::resolveEnv("ANDROID_HOME");
   config.javaHome = funkin::resolveEnv("JAVA_HOME");
   config.hxcppDir = funkin::resolveEnv("HXCPP");

   funkin::Compiler compiler(config);
   return compiler.validate();
}

DEFINE_PRIM(val, funkin_compiler_platform, vv)
{
   return alloc_string(funkin::platformToString(funkin::resolvePlatform()).c_str());
}

DEFINE_PRIM(val, funkin_compiler_arch, vv)
{
   return alloc_string(funkin::archToString(funkin::resolveArch()).c_str());
}

}
