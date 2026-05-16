namespace scheme;

public class PrimitiveRecordRef : Primitive
{
    public override string Name() => "record-ref";

    public override string Info() =>
        "Syntax: (record-ref record index)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the value of the record slot at the given index.\n" +
        "Example:\n" +
        "  (let ((r (make-record 3))) (record-set! r 0 'a) (record-ref r 0)) => a";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        Record r = Value.AsRecord(arguments[0]);
        int index = IntegerMath.ToInt(arguments[1]);
        return r.Fields[index];
    }
}
