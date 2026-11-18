namespace scheme;

public class PrimitiveStringToLatin1 : Primitive
{
    public override string Name()
    {
        return "string->latin1";
    }

    public override string Info()
    {
        return
            "Syntax: (string->latin1 s [replacement [start [end]]])\n" +
            "Library: (scm bytevector)\n" +
            "Description: Encodes the string s (or its range from start to end) as\n" +
            "ISO-8859-1 (Latin-1) and returns a bytevector. A character above #xFF\n" +
            "(a surrogate pair counts as one character) is an error unless\n" +
            "replacement is given: a byte value 0-255 written in its place.\n" +
            "Example:\n" +
            "  (string->latin1 \"a\\xE4;\") => #u8(97 228)\n" +
            "  (string->latin1 \"a\\x20AC;\" 63) => #u8(97 63)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 4);
        char[] s = Value.AsString(arguments[0]);
        int replacement = -1;
        if (arguments.Length > 1 && !arguments[1].Equals(Value.F))
        {
            replacement = IntegerMath.ToInt(arguments[1]);
            if (replacement < 0 || replacement > 255)
                throw new SchemeError(pos, "string->latin1: replacement ~a is not a byte", (long) replacement);
        }
        int start = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : 0;
        int end = arguments.Length > 3 ? IntegerMath.ToInt(arguments[3]) : s.Length;
        if (start < 0 || end > s.Length || start > end)
            throw new SchemeError(pos, "string->latin1: invalid range");
        var output = new byte[end - start];
        int n = 0;
        for (int i = start; i < end; i++)
        {
            char c = s[i];
            if (c <= 0xFF)
            {
                output[n++] = (byte) c;
                continue;
            }
            if (replacement < 0)
                throw new SchemeError(pos, "string->latin1: character #x~a at index ~a has no Latin-1 encoding",
                                      ((int) c).ToString("X"), (long) i);
            output[n++] = (byte) replacement;
            if (char.IsHighSurrogate(c) && i + 1 < end && char.IsLowSurrogate(s[i + 1])) i++;
        }
        if (n == output.Length) return output;
        var trimmed = new byte[n];
        Array.Copy(output, trimmed, n);
        return trimmed;
    }
}
