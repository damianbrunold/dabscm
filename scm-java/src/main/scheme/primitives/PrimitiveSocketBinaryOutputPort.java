package scheme.primitives;
import scheme.*;

public class PrimitiveSocketBinaryOutputPort extends Primitive {
    @Override
    public String name() { return "socket-binary-output-port"; }

    @Override
    public String info() {
        return "Syntax: (socket-binary-output-port socket)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Returns the binary output port for writing raw bytes to the socket.\n" +
               "Example:\n" +
               "  (write-u8 65 (socket-binary-output-port sock))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        if (ss.binaryOutputPort == null)
            ss.binaryOutputPort = new BinaryOutputStream(ss.networkOutputStream, false);
        return ss.binaryOutputPort;
    }
}
