package scheme.primitives;
import scheme.*;

public class PrimitiveTcpListenerP extends Primitive {
    @Override
    public String name() { return "tcp-listener?"; }

    @Override
    public String info() {
        return "Syntax: (tcp-listener? x)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns #t if x is a TCP listener.\n" +
               "Example:\n" +
               "  (tcp-listener? (tcp-listen 8080)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeListener
            ? Value.T : Value.F;
    }
}
