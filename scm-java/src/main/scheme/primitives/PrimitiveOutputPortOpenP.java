package scheme.primitives;

import scheme.*;

public class PrimitiveOutputPortOpenP extends Primitive {
    @Override public String name() { return "output-port-open?"; }
    @Override public String info() {
        return "Syntax: (output-port-open? port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if port is still open, otherwise returns #f.\n" +
               "Example:\n" +
               "  (define p (open-output-string))\n" +
               "  (output-port-open? p) => #t\n" +
               "  (close-output-port p)\n" +
               "  (output-port-open? p) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isBinaryOutputPort(arguments[0]))
            return Value.asBinaryOutputPort(arguments[0]).isOpen;
        if (arguments[0] instanceof TextOutputStream)
            return ((TextOutputStream) arguments[0]).isOpen;
        return true;
    }
}
