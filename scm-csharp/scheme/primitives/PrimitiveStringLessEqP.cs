namespace scheme;

public class PrimitiveStringLessEqP : Primitive
{
    public override string Name()
    {
        return "string<=?";
    }

    public override string Info()
    {
        return
            "Syntax: (string<=? s1 s2 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if the strings are monotonically non-increasing in lexicographic order, otherwise returns #f.\n" +
            "Example:\n" +
            "  (string<=? \"a\" \"b\") => #t\n" +
            "  (string<=? \"abc\" \"abc\") => #t\n" +
            "  (string<=? \"b\" \"a\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        object current = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            object next = arguments[i];
            int cmp = String.Compare(new String(Value.AsString(current)), new String(Value.AsString(next)), StringComparison.Ordinal);
            if (!(cmp <= 0)) return false;
            current = next;
        }
        return true;
    }
}
