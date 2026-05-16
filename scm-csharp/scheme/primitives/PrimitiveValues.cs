namespace scheme;

public class PrimitiveValues : Primitive
{
    public override string Name()
    {
        return "values";
    }

    public override string Info()
    {
        return
            "Syntax: (values obj ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns all of its arguments as multiple values. Used with call-with-values to pass multiple results between procedures.\n" +
            "Example:\n" +
            "  (values 1 2 3) => 1 2 3\n" +
            "  (call-with-values (lambda () (values 4 5)) +) => 9";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments) {
        if (arguments.Length == 1) return arguments[0];
        Values result = new Values();
        result.values = arguments; // TODO maybe need to copy?
        return result;
    }
}
