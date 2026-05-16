namespace scheme;

public class PrimitiveMakeRecord : Primitive
{
    public override string Name() => "make-record";

    public override string Info() =>
        "Syntax: (make-record size)\n" +
        "Library: (scm core)\n" +
        "Description: Creates a new record with size slots, all initialized to #f.\n" +
        "Example:\n" +
        "  (make-record 3) => #<record>";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        int size = IntegerMath.ToInt(arguments[0]);
        return new Record(size);
    }
}
