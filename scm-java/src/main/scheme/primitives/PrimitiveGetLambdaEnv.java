package scheme.primitives;

import scheme.*;

public class PrimitiveGetLambdaEnv extends Primitive {
    @Override
    public String name() {
        return "get-lambda-env";
    }

    @Override
    public String info() {
        return "Syntax: (get-lambda-env fn)\n" +
               "Library: (scm compile)\n" +
               "Description: Returns the closed-over environment of the lambda fn.\n" +
               "Example:\n" +
               "  (let ((x 42)) (get-lambda-env (lambda () x)))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asLambda(arguments[0]).env;
    }
}
