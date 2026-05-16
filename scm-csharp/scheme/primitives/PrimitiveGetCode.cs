using System.Text;

namespace scheme;

public class PrimitiveGetCode : Primitive
{
    public override string Name()
    {
        return "get-code";
    }

    public override string Info()
    {
        return
            "Syntax: (get-code fn)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns the bytecode instructions of the lambda fn as a list of strings.\n" +
            "Example:\n" +
            "  (get-code (lambda (x) x)) => (\"LOAD_ARG 0\" ...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        List<object> result = new();
        foreach (var instruction in Value.AsLambda(arguments[0]).code)
        {
            result.Add(instruction.ToString().ToCharArray());
        }
        return Pair.List(result.ToArray());
    }
}
