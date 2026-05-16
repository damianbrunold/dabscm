namespace scheme;

public class PrimitiveSysOSVersion : Primitive
{
    public override string Name()
    {
        return "sys-os-version";
    }

    public override string Info()
    {
        return
            "Syntax: (sys-os-version)\n" +
            "Library: (scm system)\n" +
            "Description: Returns a list describing the operating system: (platform version-string major minor service-pack).\n" +
            "Example:\n" +
            "  (sys-os-version) => (linux \"Unix 5.15.0.0\" 5 15 \"\")";
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
        var list = new object[] {
            Value.Intern(platform),
            os.VersionString.ToCharArray(),
            (long) os.Version.Major,
            (long) os.Version.Minor,
            os.ServicePack.ToCharArray()
        };
        return Pair.List(list);
    }
}
