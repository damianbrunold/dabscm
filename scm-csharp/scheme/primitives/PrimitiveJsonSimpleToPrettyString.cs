using System.Text;

namespace scheme;

public class PrimitiveJsonSimpleToPrettyString : Primitive
{
    public override string Name()
    {
        return "json-simple->pretty-string";
    }

    public override string Info()
    {
        return
            "Syntax: (json->pretty-string val)\n" +
            "Library: (scm json simple)\n" +
            "Description: Returns two-space-indented JSON text for val as a string\n" +
            "  (see json-write-pretty).\n" +
            "Example:\n" +
            "  (json->pretty-string '((\"a\" . 1))) => \"{\\n  \\\"a\\\": 1\\n}\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var sb = new StringBuilder();
        Go(arguments[0], 0, sb, pos);
        return sb.ToString().ToCharArray();
    }

    private static void Indent(StringBuilder sb, int n)
    {
        for (int i = 0; i < 2 * n; i++) sb.Append(' ');
    }

    private static void Go(object val, int depth, StringBuilder sb, SourcePos? pos)
    {
        if (Value.IsVector(val))
        {
            object[] vec = Value.AsVector(val);
            int n = vec.Length;
            if (n == 0) { sb.Append("[]"); return; }
            sb.Append("[\n");
            for (int i = 0; i < n; i++)
            {
                Indent(sb, depth + 1);
                Go(vec[i], depth + 1, sb, pos);
                if (i < n - 1) sb.Append(',');
                sb.Append('\n');
            }
            Indent(sb, depth);
            sb.Append(']');
            return;
        }
        if (Value.IsNil(val)) { sb.Append("{}"); return; }
        if (Value.IsPair(val))
        {
            sb.Append("{\n");
            object items = val;
            while (Value.IsPair(items))
            {
                Pair entry = Value.AsPair(items);
                if (!Value.IsPair(entry.car))
                    throw new SchemeError(pos, "json-write: object entry is not a pair: ~s", entry.car);
                Pair kv = Value.AsPair(entry.car);
                if (!Value.IsString(kv.car))
                    throw new SchemeError(pos, "json-write: object key is not a string: ~s", kv.car);
                Indent(sb, depth + 1);
                PrimitiveJsonSimpleToString.WriteString(Value.AsString(kv.car), sb);
                sb.Append(": ");
                Go(kv.cdr, depth + 1, sb, pos);
                if (Value.IsPair(entry.cdr)) sb.Append(',');
                sb.Append('\n');
                items = entry.cdr;
            }
            Indent(sb, depth);
            sb.Append('}');
            return;
        }
        // Scalars use the compact writer, matching the original implementation.
        PrimitiveJsonSimpleToString.Write(val, sb, pos);
    }
}
