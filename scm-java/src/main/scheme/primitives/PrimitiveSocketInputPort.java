package scheme.primitives;
import scheme.*;

public class PrimitiveSocketInputPort extends Primitive {
    @Override
    public String name() { return "socket-input-port"; }

    @Override
    public String info() {
        return "Syntax: (socket-input-port socket)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns the textual input port for reading from the socket.\n" +
               "Example:\n" +
               "  (read-line (socket-input-port sock))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        return ss.inputPort;
    }
}
