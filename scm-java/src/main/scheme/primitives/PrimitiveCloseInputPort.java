package scheme.primitives;

import scheme.*;

public class PrimitiveCloseInputPort extends Primitive {
    @Override
    public String name() {
        return "close-input-port";
    }

    @Override
    public String info() {
        return "Syntax: (close-input-port port)\n" +
               "Library: (scheme base)\n" +
               "Description: Closes the input port, releasing any resources. It is an error to read from a closed port.\n" +
               "Example:\n" +
               "  (let ((p (open-input-file \"data.txt\")))\n" +
               "    (close-input-port p))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            if (Value.isBinaryInputPort(arguments[0]))
                Value.asBinaryInputPort(arguments[0]).close();
            else
                Value.asInputPort(arguments[0]).close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "close-input-port: io failure: ~s", e.getMessage());
        }
    }
}
