package scheme.primitives;
import scheme.*;

public class PrimitiveSocketBinaryInputPort extends Primitive {
    @Override
    public String name() { return "socket-binary-input-port"; }

    @Override
    public String info() {
        return "Syntax: (socket-binary-input-port socket)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns the binary input port for reading raw bytes from the socket.\n" +
               "Example:\n" +
               "  (read-u8 (socket-binary-input-port sock))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        if (ss.binaryInputPort == null)
            ss.binaryInputPort = new BinaryInputStream(ss.networkInputStream);
        return ss.binaryInputPort;
    }
}
