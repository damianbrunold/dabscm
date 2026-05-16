package scheme;

public class PrimitiveRecordP extends Primitive {
    public String name() { return "record?"; }

    public String info() {
        return "Syntax: (record? obj)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if obj is a record, #f otherwise.\n" +
               "Example:\n" +
               "  (record? (make-record 3)) => #t\n" +
               "  (record? #(1 2 3)) => #f";
    }

    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isRecord(arguments[0]);
    }
}
