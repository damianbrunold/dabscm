namespace scheme;

public class PrimitiveSysNumCPUCores : Primitive
{
    public override string Name()
    {
        return "sys-num-cpu-cores";
    }

    public override string Info()
    {
        return
            "Syntax: (sys-num-cpu-cores)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the number of logical CPU cores available to the current process as an integer.\n" +
            "Example:\n" +
            "  (sys-num-cpu-cores) => 8";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return (long) Environment.ProcessorCount;
    }
}
