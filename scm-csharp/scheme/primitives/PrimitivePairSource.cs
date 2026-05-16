namespace scheme;

public class PrimitivePairSource : Primitive
{
    public override string Name() => "%pair-source";

    public override string Info() =>
        "Syntax: (%pair-source pair)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the source position of a pair as (filename . line), or #f if no position is available.\n" +
        "Example:\n" +
        "  (%pair-source '(a b)) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsPair(arguments[0]))
        {
            var p = Value.AsPair(arguments[0]).pos;
            if (p != null)
                return new Pair(p.filename.ToCharArray(), p.line);
        }
        return Value.F;
    }
}
