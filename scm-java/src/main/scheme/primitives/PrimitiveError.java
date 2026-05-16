package scheme.primitives;

import scheme.*;

import java.util.List;
import java.util.ArrayList;

public class PrimitiveError extends Primitive {
    @Override
    public String name() {
        return "error";
    }

    @Override
    public String info() {
        return "Syntax: (error message obj ...) (error who message obj ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Raises an error. In R7RS form, message is a string and obj ... are irritants. In SRFI-23 form, who is a symbol identifying the caller.\n" +
               "Example:\n" +
               "  (error \"out of range\" 42)\n" +
               "  (error 'my-proc \"value out of range\" 42)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        String message;
        Object[] irritants;
        if (Value.isSymbol(arguments[0])) {
            // SRFI-23: (error who message irritant ...)
            checkArgs(pos, arguments, 2, -1);
            String who = Value.asSymbol(arguments[0]);
            message = who + ": " + new String(Value.asString(arguments[1]));
            irritants = new Object[arguments.length - 2];
            for (int i = 0; i < irritants.length; i++) irritants[i] = arguments[i + 2];
        } else {
            // R7RS: (error message irritant ...)
            message = new String(Value.asString(arguments[0]));
            irritants = new Object[arguments.length - 1];
            for (int i = 0; i < irritants.length; i++) irritants[i] = arguments[i + 1];
        }
        ErrorObject errorObj = new ErrorObject(message, irritants);
        throw new SchemeError(pos, errorObj);
    }
}
