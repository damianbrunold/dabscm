package scheme.primitives;

import java.util.List;

import scheme.*;

public class PrimitiveSetCodeB extends Primitive {
    @Override
    public String name() {
        return "set-code!";
    }

    @Override
    public String info() {
        return "Syntax: (set-code! fn instructions)\n" +
               "Library: (scm compile)\n" +
               "Description: Replaces the bytecode instructions of the lambda fn with the given instructions list. Used for low-level code patching.\n" +
               "Example:\n" +
               "  (define f (lambda (x) x))\n" +
               "  (set-code! f (get-code f))";
    }
    
    @SuppressWarnings("unchecked")
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        Lambda fn = Value.asLambda(arguments[0]);
        fn.code = (List<Instruction>) arguments[1];
        return new Values();
    }
}
