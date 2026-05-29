using System;
using System.IO;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveParentPid : Primitive
{
    public override string Name() => "parent-pid";

    public override string Info() =>
        "Syntax: (parent-pid)\n" +
        "Library: (scm system)\n" +
        "Description: Returns the OS process id of the parent of the current Scheme\n" +
        "  process, or #f if it cannot be determined. On Linux this reads /proc/self/stat;\n" +
        "  on other platforms #f may be returned.\n" +
        "Example:\n" +
        "  (parent-pid) => 12340";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux)) return Value.F;
        long? ppid = ProcUtil.ReadPpid("self");
        return ppid.HasValue ? (object)(long)ppid.Value : Value.F;
    }
}
