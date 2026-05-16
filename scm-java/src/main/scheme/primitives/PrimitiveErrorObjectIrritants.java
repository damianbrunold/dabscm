package scheme.primitives;

import scheme.*;

public class PrimitiveErrorObjectIrritants extends Primitive {
    @Override
    public String name() { return "error-object-irritants"; }

    @Override
    public String info() {
        return "Syntax: (error-object-irritants error-object)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the list of irritants (extra objects) of the given error object.\n" +
               "Example:\n" +
               "  (guard (e (#t (error-object-irritants e)))\n" +
               "    (error \"bad value\" 42)) => (42)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof ErrorObject))
            throw new SchemeError(pos, "error-object-irritants: not an error object");
        ErrorObject e = (ErrorObject) arguments[0];
        return Pair.list(e.irritants);
    }
}
