namespace scheme;

public class PrimitiveStringSetB : Primitive
{
    public override string Name()
    {
        return "string-set!";
    }

    public override string Info()
    {
        return
            "Syntax: (string-set! s k char)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Stores char in position k of the string s, mutating the string in place. It is an error if k is out of range.\n" +
            "Example:\n" +
            "  (let ((s (string-copy \"hello\")))\n" +
            "    (string-set! s 0 #\\H)\n" +
            "    s) => \"Hello\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        char[] s = Value.AsString(arguments[0]);
        s[(int) (long) arguments[1]] = Value.AsChar(arguments[2]);
        return new Values();
    }
}
