namespace scheme;

public class PrimitiveCharLessP : Primitive
{
    public override string Name()
    {
        return "char<?";
    }

    public override string Info()
    {
        return
            "Syntax: (char<? char1 char2 char3 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if the character arguments are monotonically increasing.\n" +
            "Example:\n" +
            "  (char<? #\\a #\\b) => #t\n" +
            "  (char<? #\\a #\\a) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        object current = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            object next = arguments[i];
            if (!(Value.AsChar(current) < Value.AsChar(next))) return false;
            current = next;
        }
        return true;
    }
}
