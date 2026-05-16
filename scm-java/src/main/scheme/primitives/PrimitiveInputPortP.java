package scheme.primitives;

import scheme.*;

public class PrimitiveInputPortP extends Primitive {
    @Override
    public String name() {
        return "input-port?";
    }

    @Override
    public String info() {
        return "Syntax: (input-port? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an input port, otherwise returns #f.\n" +
               "Example:\n" +
               "  (input-port? (open-input-string \"abc\")) => #t\n" +
               "  (input-port? (open-output-string)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isInputPort(arguments[0]);
    }
}
