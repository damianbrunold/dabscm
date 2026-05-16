package scheme.primitives;

import scheme.*;

public class PrimitiveCloseOutputPort extends Primitive {
    @Override
    public String name() {
        return "close-output-port";
    }

    @Override
    public String info() {
        return "Syntax: (close-output-port port)\n" +
               "Library: (scheme base)\n" +
               "Description: Closes the output port, flushing any buffered output and releasing resources.\n" +
               "Example:\n" +
               "  (let ((p (open-output-file \"out.txt\")))\n" +
               "    (close-output-port p))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            if (Value.isBinaryOutputPort(arguments[0]))
                Value.asBinaryOutputPort(arguments[0]).close();
            else
                Value.asOutputPort(arguments[0]).close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "close-output-port: io failure: ~s", e.getMessage());
        }
    }
}
