namespace scheme;

public class PrimitiveGetLambdaEnv : Primitive
{
    public override string Name()
    {
        return "get-lambda-env";
    }

    public override string Info()
    {
        return
            "Syntax: (get-lambda-env fn)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns the closed-over environment of the lambda fn.\n" +
            "Example:\n" +
            "  (let ((x 42)) (get-lambda-env (lambda () x)))";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsLambda(arguments[0]).env;
    }
}
