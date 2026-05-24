using System.Text;

namespace scheme;

public class PrimitivePgParseDatarow : Primitive
{
    public override string Name() => "pg-parse-datarow";

    public override string Info() =>
        "Syntax: (pg-parse-datarow body)\n" +
        "Library: (scm database postgres)\n" +
        "Description: Parses a PostgreSQL DataRow message body bytevector " +
        "and returns a vector with one element per column. Each element is " +
        "a UTF-8 decoded string, an empty string for zero-length values, or " +
        "#f for NULL. body must point at the column-count int16; the 5-byte " +
        "type+length frame must already be stripped.\n" +
        "Example:\n" +
        "  (pg-parse-datarow body) => #(\"1\" \"alice\" #f)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            byte[] body = Value.AsBytevector(arguments[0]);
            int off = 0;
            int ncols = (body[off] << 8) | body[off + 1];
            off += 2;
            object[] result = new object[ncols];
            for (int i = 0; i < ncols; i++)
            {
                int len = (body[off] << 24)
                        | (body[off + 1] << 16)
                        | (body[off + 2] << 8)
                        |  body[off + 3];
                off += 4;
                if (len == -1)
                {
                    result[i] = false;
                }
                else if (len == 0)
                {
                    result[i] = new char[0];
                }
                else
                {
                    string s = Encoding.UTF8.GetString(body, off, len);
                    result[i] = s.ToCharArray();
                    off += len;
                }
            }
            return result;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "pg-parse-datarow: parse failure: ~a", e.Message);
        }
    }
}
