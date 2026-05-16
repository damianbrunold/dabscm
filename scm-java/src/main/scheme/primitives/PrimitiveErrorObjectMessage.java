package scheme.primitives;

import scheme.*;

public class PrimitiveErrorObjectMessage extends Primitive {
    @Override
    public String name() { return "error-object-message"; }

    @Override
    public String info() {
        return "Syntax: (error-object-message error-object)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the message string of the given error object.\n" +
               "Example:\n" +
               "  (guard (e (#t (error-object-message e)))\n" +
               "    (error \"bad value\" 42)) => \"bad value\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof ErrorObject))
            throw new SchemeError(pos, "error-object-message: not an error object");
        ErrorObject e = (ErrorObject) arguments[0];
        return e.message.toCharArray();
    }
}
