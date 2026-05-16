package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalP extends Primitive {
    @Override
    public String name() {
        return "terminal?";
    }

    @Override
    public String info() {
        return "Syntax: (terminal?)\n" +
               "Syntax: (terminal? which)\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns #t if the process is connected to a terminal.\n" +
               "If which is 'input, checks only the input stream.\n" +
               "If which is 'output, checks only the output stream.\n" +
               "With no arguments, returns #t only if both input and output are terminals.\n" +
               "Example:\n" +
               "  (terminal?) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        if (arguments.length == 1) {
            String which = Value.asSymbol(arguments[0]);
            if (which.equals("input") || which.equals("output")) {
                return System.console() != null;
            } else {
                throw new SchemeError(pos, "terminal?: expected 'input or 'output, got ~s", Value.printRep(arguments[0]));
            }
        }
        return System.console() != null;
    }
}
