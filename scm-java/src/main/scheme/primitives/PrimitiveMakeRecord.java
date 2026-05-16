package scheme;

public class PrimitiveMakeRecord extends Primitive {
    public String name() { return "make-record"; }

    public String info() {
        return "Syntax: (make-record size)\n" +
               "Library: (scm core)\n" +
               "Description: Creates a new record with size slots, all initialized to #f.\n" +
               "Example:\n" +
               "  (make-record 3) => #<record>";
    }

    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        int size = IntegerMath.toInt(arguments[0]);
        return new Record(size);
    }
}
