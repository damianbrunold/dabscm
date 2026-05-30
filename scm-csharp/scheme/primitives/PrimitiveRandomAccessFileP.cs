namespace scheme;

public class PrimitiveRandomAccessFileP : Primitive
{
    public override string Name() => "random-access-file?";
    public override string Info() =>
        "Syntax: (random-access-file? obj)\n" +
        "Library: (scm random access)\n" +
        "Description: Returns #t if obj is a random-access file handle (as returned by open-random-access-file), otherwise #f.\n" +
        "Example:\n" +
        "  (random-access-file? (open-random-access-file \"x\" 'write)) => #t\n" +
        "  (random-access-file? 42) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0])
            && Value.AsNativeValue(arguments[0]).value is RandomAccessFileHandle;
    }
}
