namespace scheme;

public class PrimitiveMakeParameterCore : Primitive
{
    public override string Name() => "%make-parameter";

    public override string Info() =>
        "Syntax: (%make-parameter init)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns a fresh parameter object with `init` as its default value. The returned object is callable: zero args reads the calling thread's current value (defaulting to `init`), one arg sets it. The Scheme-level make-parameter wraps this to apply an optional converter.\n" +
        "Example:\n" +
        "  (define p (%make-parameter 10))\n" +
        "  (p)     => 10\n" +
        "  (p 20)\n" +
        "  (p)     => 20";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return new Parameter(arguments[0]);
    }
}
