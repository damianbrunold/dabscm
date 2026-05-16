package scheme.primitives;
import scheme.*;

public class PrimitiveSocketP extends Primitive {
    @Override
    public String name() { return "socket?"; }

    @Override
    public String info() {
        return "Syntax: (socket? x)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns #t if x is a TCP socket.\n" +
               "Example:\n" +
               "  (socket? (tcp-connect \"localhost\" 8080)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeSocket
            ? Value.T : Value.F;
    }
}
