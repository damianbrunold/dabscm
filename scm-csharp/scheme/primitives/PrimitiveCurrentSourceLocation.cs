namespace scheme;

public class PrimitiveCurrentSourceLocation : Primitive
{
    public override string Name() => "current-source-location";

    public override string Info() =>
        "Syntax: (current-source-location)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the source position of the call site as (filename line column), or #f if no position is available.\n" +
        "Example:\n" +
        "  (current-source-location) => (\"file.scm\" 42 0)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        if (pos != null)
            return pos.ToSexpr();
        return Value.F;
    }
}
