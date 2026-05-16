package scheme.primitives;

import scheme.*;

import java.util.ArrayList;

public class PrimitiveMakeErrorObject extends Primitive {
    @Override
    public String name() { return "%make-error-object"; }

    @Override
    public String info() {
        return "Syntax: (%make-error-object message irritants)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Creates an error object with the given message string and list of irritant objects.\n" +
               "Example:\n" +
               "  (%make-error-object \"bad value\" '(42))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 2, 2);
        String message = new String(Value.asString(args[0]));
        // args[1] is a Scheme list of irritants
        ArrayList<Object> irritants = new ArrayList<>();
        Object lst = args[1];
        while (lst != Value.NIL) {
            Pair pair = Value.asPair(lst);
            irritants.add(pair.car);
            lst = pair.cdr;
        }
        return new ErrorObject(message, irritants.toArray());
    }
}
