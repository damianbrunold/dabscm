package scheme.primitives;

import scheme.*;

public class PrimitiveOutputPortP extends Primitive {
    @Override
    public String name() {
        return "output-port?";
    }

    @Override
    public String info() {
        return "Syntax: (output-port? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an output port, otherwise returns #f.\n" +
               "Example:\n" +
               "  (output-port? (open-output-string)) => #t\n" +
               "  (output-port? (current-output-port)) => #t\n" +
               "  (output-port? 42) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isOutputPort(arguments[0]);
    }
}
