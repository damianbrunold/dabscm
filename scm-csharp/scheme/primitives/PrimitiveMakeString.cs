using System.Text;

namespace scheme;

public class PrimitiveMakeString : Primitive
{
    public override string Name()
    {
        return "make-string";
    }

    public override string Info()
    {
        return
            "Syntax: (make-string k) (make-string k char)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns a newly allocated mutable string of k characters. If char is given, all characters are initialized to char; otherwise they are spaces.\n" +
            "Example:\n" +
            "  (make-string 3 #\\x) => \"xxx\"\n" +
            "  (make-string 3) => \"   \"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        int n = IntegerMath.ToInt(arguments[0]);
        char ch = ' ';
        if (arguments.Length == 2) ch = Value.AsChar(arguments[1]);
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < n; i++)
        {
            result.Append(ch);
        }
        return result.ToString().ToCharArray();
    }
}
