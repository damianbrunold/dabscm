package scheme.primitives;

import scheme.*;

public class PrimitiveLambdaP extends Primitive {
    @Override
    public String name() {
        return "lambda?";
    }

    @Override
    public String info() {
        return "Syntax: (lambda? obj)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if obj is a compiled lambda (procedure), otherwise returns #f.\n" +
               "Example:\n" +
               "  (lambda? (lambda (x) x)) => #t\n" +
               "  (lambda? 42) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isLambda(arguments[0]);
    }
}
