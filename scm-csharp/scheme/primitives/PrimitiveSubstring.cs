namespace scheme;

public class PrimitiveSubstring : Primitive
{
    public override string Name()
    {
        return "substring";
    }

    public override string Info()
    {
        return
            "Syntax: (substring s start end)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated string containing the characters of s from index start (inclusive) to end (exclusive).\n" +
            "Example:\n" +
            "  (substring \"hello\" 1 3) => \"el\"\n" +
            "  (substring \"hello\" 0 5) => \"hello\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        char[] s = Value.AsString(arguments[0]);
        int start = 0;
        int end = s.Length;
        if (arguments.Length > 1)
        {
            start = IntegerMath.ToInt(arguments[1]);
            if (start < 0) start = s.Length + start;
            if (start < 0) throw OutOfRange(pos, arguments[1]);
        }
        if (arguments.Length > 2)
        {
            end = IntegerMath.ToInt(arguments[2]);
            if (end < 0) end = s.Length + end;
            if (end < 0) throw OutOfRange(pos, arguments[2]);
        }
        if (start > end || end > s.Length)
        {
            object[] irritants = new object[arguments.Length - 1];
            Array.Copy(arguments, 1, irritants, 0, irritants.Length);
            throw OutOfRange(pos, irritants);
        }
        char[] result = new char[end - start];
        for (var i = 0; i < result.Length; i++) {
            result[i] = s[start + i];
        }
        return result;
    }

    private static SchemeError OutOfRange(SourcePos? pos, params object[] irritants)
        => new SchemeError(pos, new ErrorObject("substring: index out of range", irritants));
}
