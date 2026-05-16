namespace scheme;

public class PrimitiveSysScmTechnology : Primitive
{
    public override string Name() => "sys-scm-technology";

    public override string Info() =>
        "Syntax: (sys-scm-technology)\n" +
        "Library: (scm system)\n" +
        "Description: Returns a symbol identifying the SCM implementation technology: csharp or java.\n" +
        "Example:\n" +
        "  (sys-scm-technology) => csharp";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return Value.Intern("csharp");
    }
}
