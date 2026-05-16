package scheme;

public class PrimitiveRecordRef extends Primitive {
    public String name() { return "record-ref"; }

    public String info() {
        return "Syntax: (record-ref record index)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the value of the record slot at the given index.\n" +
               "Example:\n" +
               "  (let ((r (make-record 3))) (record-set! r 0 'a) (record-ref r 0)) => a";
    }

    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Record r = Value.asRecord(arguments[0]);
        int index = IntegerMath.toInt(arguments[1]);
        return r.fields[index];
    }
}
