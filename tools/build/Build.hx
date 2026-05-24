class Build extends hxcpp.Builder
{
    override public function wantLegacyIosBuild():Bool { return true; }
    override public function wantWindows64():Bool { return true; }

    override public function runBuild(target:String, isStatic:Bool, arch:String, inFlags:Array<String>):Void
    {
        var here:String = Sys.getCwd().split("\\").join("/");

        var parts:Array<String> = here.split("/");
        while (parts.length > 0 && parts[parts.length - 1] == "")
            parts.pop();
        if (parts.length > 0)
            parts.pop();

        var hxcppDir:String = parts.join("/");
        var args:Array<String> = ["run.n", "Build.xml"].concat(inFlags).concat([here]);

        Sys.setCwd(hxcppDir);
        Sys.println("neko " + args.join(" "));

        var exitCode:Int = Sys.command("neko", args);
        if (exitCode != 0)
        {
            Sys.println('#### Build failed (exit $exitCode): neko ${inFlags.join(" ")}');
            Sys.exit(exitCode);
        }

        Sys.setCwd(here);
    }

    public static function main():Void
    {
        new Build(Sys.args());
    }
}
