namespace scheme;

public class PrimitiveRecordSetB : Primitive
{
    public override string Name() => "record-set!";

    public override string Info() =>
        "Syntax: (record-set! record index value)\n" +
        "Library: (scm core)\n" +
        "Description: Sets the record slot at the given index to value.\n" +
        "Example:\n" +
        "  (let ((r (make-record 3))) (record-set! r 0 'hello) (record-ref r 0)) => hello";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        Record r = Value.AsRecord(arguments[0]);
        int index = IntegerMath.ToInt(arguments[1]);
        r.Fields[index] = arguments[2];
        return new Values();
    }
}
