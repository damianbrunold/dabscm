namespace scheme;

public class PrimitiveRecordP : Primitive
{
    public override string Name() => "record?";

    public override string Info() =>
        "Syntax: (record? obj)\n" +
        "Library: (scm core)\n" +
        "Description: Returns #t if obj is a record, #f otherwise.\n" +
        "Example:\n" +
        "  (record? (make-record 3)) => #t\n" +
        "  (record? #(1 2 3)) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsRecord(arguments[0]);
    }
}
