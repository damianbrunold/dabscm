namespace scheme;

public class PrimitiveSysMachineName : Primitive
{
    public override string Name()
    {
        return "sys-machine-name";
    }

    public override string Info()
    {
        return
            "Syntax: (sys-machine-name)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the hostname of the current machine as a string.\n" +
            "Example:\n" +
            "  (sys-machine-name) => \"myhost\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return Environment.MachineName.ToCharArray();
    }
}
