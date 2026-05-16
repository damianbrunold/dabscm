namespace scheme;

public class PrimitiveStringEqP : Primitive
{
    public override string Name()
    {
        return "string=?";
    }

    public override string Info()
    {
        return
            "Syntax: (string=? s1 s2 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if all the given strings are equal to each other, otherwise returns #f.\n" +
            "Example:\n" +
            "  (string=? \"abc\" \"abc\") => #t\n" +
            "  (string=? \"abc\" \"def\") => #f\n" +
            "  (string=? \"x\" \"x\" \"x\") => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        char[] current = Value.AsString(arguments[0]);
        for (int i = 1; i < arguments.Length; i++)
        {
            char[] next = Value.AsString(arguments[i]);
            //if (!(new String(Value.AsString(current)).Equals(new String(Value.AsString(next))))) return false;
            if (current.Length != next.Length) return false;
            for (var idx = 0; idx < current.Length; idx++)
            {
                if (current[idx] != next[idx]) return false;
            }
            //current = next;
        }
        return true;
    }
}
