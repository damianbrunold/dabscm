namespace scheme;

public class PrimitiveHtmlEscape : Primitive
{
    public override string Name() => "html-escape";

    public override string Info() =>
        "Syntax: (html-escape s)\n" +
        "Library: (scm html)\n" +
        "Description: Escapes the five HTML metacharacters (&, <, >, \", ') in s so the result is safe to splice into HTML text content or attribute values.\n" +
        "Example:\n" +
        "  (html-escape \"a < b & c\") => \"a &lt; b &amp; c\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        char[] s = Value.AsString(arguments[0]);
        int n = s.Length;
        int needed = 0;
        for (int i = 0; i < n; i++)
        {
            char c = s[i];
            switch (c)
            {
                case '<': case '>':  needed += 4; break;
                case '&': case '\'': needed += 5; break;
                case '"':            needed += 6; break;
                default:             needed += 1; break;
            }
        }
        if (needed == n)
        {
            return s;
        }
        char[] outBuf = new char[needed];
        int j = 0;
        for (int i = 0; i < n; i++)
        {
            char c = s[i];
            switch (c)
            {
                case '<':  outBuf[j++]='&'; outBuf[j++]='l'; outBuf[j++]='t'; outBuf[j++]=';'; break;
                case '>':  outBuf[j++]='&'; outBuf[j++]='g'; outBuf[j++]='t'; outBuf[j++]=';'; break;
                case '&':  outBuf[j++]='&'; outBuf[j++]='a'; outBuf[j++]='m'; outBuf[j++]='p'; outBuf[j++]=';'; break;
                case '"':  outBuf[j++]='&'; outBuf[j++]='q'; outBuf[j++]='u'; outBuf[j++]='o'; outBuf[j++]='t'; outBuf[j++]=';'; break;
                case '\'': outBuf[j++]='&'; outBuf[j++]='#'; outBuf[j++]='3'; outBuf[j++]='9'; outBuf[j++]=';'; break;
                default:   outBuf[j++] = c; break;
            }
        }
        return outBuf;
    }
}
