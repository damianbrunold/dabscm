package scheme.primitives;
import scheme.*;

public class PrimitiveSocketOutputPort extends Primitive {
    @Override
    public String name() { return "socket-output-port"; }

    @Override
    public String info() {
        return "Syntax: (socket-output-port socket)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns the textual output port for writing to the socket.\n" +
               "Example:\n" +
               "  (display \"hello\" (socket-output-port sock))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        return ss.outputPort;
    }
}
