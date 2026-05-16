namespace scheme;

public class PrimitiveSysPlatform : Primitive
{
    public override string Name()
    {
        return "sys-platform";
    }

    public override string Info()
    {
        return
            "Syntax: (sys-platform)\n" +
            "Library: (scm system)\n" +
            "Description: Returns a symbol identifying the current operating system platform: windows, linux, or unknown.\n" +
            "Example:\n" +
            "  (sys-platform) => linux";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var os = Environment.OSVersion;
        string platform = "unknown";
        PlatformID pid = os.Platform;
        switch (pid)
        {
            case PlatformID.Win32NT:
            case PlatformID.Win32S:
            case PlatformID.Win32Windows:
            case PlatformID.WinCE:
                platform = "windows";
            break;
            case PlatformID.Unix:
                platform = "linux";
                break;
            default:
                break;
        }
        return Value.Intern(platform);
    }
}
