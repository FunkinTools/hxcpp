import haxe.Exception;
import haxe.Json;
import sys.io.File;

using StringTools;

typedef Haxelib = {
   var version:String;
}

typedef SemVer = {
   var major:String;
   var minor:String;
   var patch:String;
}

class Write
{
   static final HAXELIB_JSON:String    = "haxelib.json";
   static final VERSION_HEADER:String  = "include/HxcppVersion.h";
   static final HXCPP_DEFINE:String    = "HXCPP_VERSION";

   public static function main():Void
   {
      final args = Sys.args();

      if (args.length != 1 || !args[0].startsWith("v"))
         throw new Exception('Expected a version tag like v1.2.3, got: ${args.join(" ")}');

      final tagVersion     = parseVersion(args[0].substr(1), "tag");
      final json           = loadHaxelib();
      final currentVersion = parseVersion(json.version, "haxelib.json");

      validateVersionOrder(currentVersion, tagVersion);

      json.version = resolveNextVersion(currentVersion, tagVersion);

      saveHaxelib(json);
      saveVersionHeader(json.version);

      Sys.println("hxcpp_release=" + json.version);
   }

   static function parseVersion(raw:String, source:String):SemVer
   {
      return switch raw.split(".")
      {
         case [major, minor, patch]:
            { major: major, minor: minor, patch: patch };
         case _:
            throw new Exception('Invalid version format in $source: "$raw"');
      }
   }

   static function validateVersionOrder(current:SemVer, tag:SemVer):Void
   {
      final curMajor = Std.parseInt(current.major);
      final curMinor = Std.parseInt(current.minor);
      final tagMajor = Std.parseInt(tag.major);
      final tagMinor = Std.parseInt(tag.minor);

      if (curMajor < tagMajor)
         return;

      if (curMajor == tagMajor && curMinor >= tagMinor)
         return;

      throw new Exception(
         'Version in haxelib.json (${current.major}.${current.minor}.${current.patch}) '
       + 'is older than the last tag (${tag.major}.${tag.minor}.${tag.patch})'
      );
   }

   static function resolveNextVersion(current:SemVer, tag:SemVer):String
   {
      final curMajor = Std.parseInt(current.major);
      final curMinor = Std.parseInt(current.minor);
      final tagMajor = Std.parseInt(tag.major);
      final tagMinor = Std.parseInt(tag.minor);

      if (curMajor > tagMajor || curMinor > tagMinor)
         return '${current.major}.${current.minor}.0';

      final nextPatch = Std.parseInt(tag.patch) + 1;
      return '${current.major}.${current.minor}.$nextPatch';
   }

   static function loadHaxelib():Haxelib
   {
      final raw = File.getContent(HAXELIB_JSON);
      return (cast Json.parse(raw) : Haxelib);
   }

   static function saveHaxelib(json:Haxelib):Void
   {
      File.saveContent(HAXELIB_JSON, Json.stringify(json, "\t"));
   }

   static function saveVersionHeader(version:String):Void
   {
      final lines = [
         '#ifndef $HXCPP_DEFINE',
         '#define $HXCPP_DEFINE "$version"',
         '#endif'
      ];
      File.saveContent(VERSION_HEADER, lines.join("\n"));
   }
}
