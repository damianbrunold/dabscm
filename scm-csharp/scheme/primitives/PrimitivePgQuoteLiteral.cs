using System.Text;

namespace scheme;

public class PrimitivePgQuoteLiteral : Primitive
{
    public override string Name() => "pg-quote-literal";

    public override string Info() =>
        "Syntax: (pg-quote-literal s)\n" +
        "Library: (scm database postgres)\n" +
        "Description: Returns s wrapped in single quotes with internal " +
        "single quotes doubled — the SQL standard string-literal escape, " +
        "safe under PostgreSQL's default standard_conforming_strings=on " +
        "(backslashes stay literal). Use for any user-controlled string " +
        "interpolated into SQL.\n" +
        "Example:\n" +
        "  (pg-quote-literal \"O'Brien\") => \"'O''Brien'\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        char[] s = Value.AsString(arguments[0]);
        int n = s.Length;
        // Count apostrophes to size the result exactly — avoids any
        // StringBuilder grow allocation, important for multi-megabyte
        // payloads (e.g. the catalog_text.payload TOAST column).
        int quotes = 0;
        for (int i = 0; i < n; i++)
        {
            if (s[i] == '\'') quotes++;
        }
        char[] result = new char[n + quotes + 2];
        int o = 0;
        result[o++] = '\'';
        for (int i = 0; i < n; i++)
        {
            char c = s[i];
            if (c == '\'')
            {
                result[o++] = '\'';
                result[o++] = '\'';
            }
            else
            {
                result[o++] = c;
            }
        }
        result[o++] = '\'';
        return result;
    }
}
