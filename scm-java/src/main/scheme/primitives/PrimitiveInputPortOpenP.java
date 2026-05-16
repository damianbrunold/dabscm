package scheme.primitives;

import scheme.*;

public class PrimitiveInputPortOpenP extends Primitive {
    @Override public String name() { return "input-port-open?"; }
    @Override public String info() {
        return "Syntax: (input-port-open? port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the input port is still open, otherwise returns #f.\n" +
               "Example:\n" +
               "  (let ((p (open-input-string \"abc\")))\n" +
               "    (close-input-port p)\n" +
               "    (input-port-open? p)) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isBinaryInputPort(arguments[0]))
            return Value.asBinaryInputPort(arguments[0]).isOpen;
        if (arguments[0] instanceof TextStream)
            return ((TextStream) arguments[0]).isOpen;
        return true;
    }
}
