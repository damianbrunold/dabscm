package scheme;

public class PrimitiveRecordSetB extends Primitive {
    public String name() { return "record-set!"; }

    public String info() {
        return "Syntax: (record-set! record index value)\n" +
               "Library: (scm core)\n" +
               "Description: Sets the record slot at the given index to value.\n" +
               "Example:\n" +
               "  (let ((r (make-record 3))) (record-set! r 0 'hello) (record-ref r 0)) => hello";
    }

    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        Record r = Value.asRecord(arguments[0]);
        int index = IntegerMath.toInt(arguments[1]);
        r.fields[index] = arguments[2];
        return new Values();
    }
}
