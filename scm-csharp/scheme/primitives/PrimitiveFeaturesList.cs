using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveFeaturesList : Primitive
{
    public override string Name() => "%features-list";

    public override string Info() =>
        "Syntax: (%features-list)\n" +
        "Library: (scheme base)\n" +
        "Description: Internal primitive that returns the list of feature symbols for this implementation (used by (features)). Includes r7rs, scm, platform, and architecture identifiers.\n" +
        "Example:\n" +
        "  (%features-list) => (r7rs scm exact-closed ieee-float gnu-linux x86-64 little-endian)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);

        var features = new List<string> { "r7rs", "scm", "exact-closed", "ieee-float",
            "srfi-1", "srfi-2", "srfi-8", "srfi-9", "srfi-13", "srfi-14",
            "srfi-18", "srfi-19", "srfi-26", "srfi-28", "srfi-39", "srfi-64",
            "srfi-69", "srfi-95", "srfi-98", "srfi-111", "srfi-125", "srfi-128",
            "srfi-132", "srfi-133", "srfi-151", "srfi-158" };

        // OS platform
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            features.Add("gnu-linux");
            features.Add("unix");
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            features.Add("darwin");
            features.Add("unix");
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            features.Add("windows");
        }

        // Architecture
        switch (RuntimeInformation.ProcessArchitecture)
        {
            case Architecture.X64:   features.Add("x86-64"); break;
            case Architecture.X86:   features.Add("i386"); break;
            case Architecture.Arm64: features.Add("arm64"); break;
            case Architecture.Arm:   features.Add("arm"); break;
        }

        // Endianness
        features.Add(BitConverter.IsLittleEndian ? "little-endian" : "big-endian");

        object result = Value.NIL;
        for (int i = features.Count - 1; i >= 0; i--)
            result = new Pair(Value.Intern(features[i]), result);
        return result;
    }
}
