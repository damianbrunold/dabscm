using System.Text;

namespace scheme;

public class PrimitiveJsonSimpleToString : Primitive
{
    public override string Name()
    {
        return "json-simple->string";
    }

    public override string Info()
    {
        return
            "Syntax: (json->string val)\n" +
            "Library: (scm json simple)\n" +
            "Description: Returns compact JSON text for val as a string (see json-write).\n" +
            "Example:\n" +
            "  (json->string #(1 2 3)) => \"[1,2,3]\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var sb = new StringBuilder();
        Write(arguments[0], sb, pos);
        return sb.ToString().ToCharArray();
    }

    // Compact serialization of a JSON value, shared with the pretty writer.
    public static void Write(object val, StringBuilder sb, SourcePos? pos)
    {
        if (Value.IsBoolean(val)) { sb.Append(Value.AsBoolean(val) ? "true" : "false"); return; }
        if (Value.IsString(val)) { WriteString(Value.AsString(val), sb); return; }
        if (Value.IsInteger(val)) { sb.Append(val.ToString()); return; }
        if (Value.IsReal(val)) { sb.Append(Value.FormatDouble(Value.AsReal(val))); return; }
        if (Value.IsRational(val)) { sb.Append(Value.AsRational(val).ToString()); return; }
        if (Value.IsComplex(val)) { sb.Append(Value.AsComplex(val).ToString()); return; }
        if (Value.IsVector(val))
        {
            object[] vec = Value.AsVector(val);
            sb.Append('[');
            for (int i = 0; i < vec.Length; i++)
            {
                if (i > 0) sb.Append(',');
                Write(vec[i], sb, pos);
            }
            sb.Append(']');
            return;
        }
        if (Value.IsNil(val)) { sb.Append("{}"); return; }
        if (Value.IsPair(val)) { WriteObject(val, sb, pos); return; }
        if (Value.IsSymbol(val) && Value.AsSymbol(val) == "null") { sb.Append("null"); return; }
        throw new SchemeError(pos, "json-write: cannot serialize: ~s", val);
    }

    private static void WriteObject(object alist, StringBuilder sb, SourcePos? pos)
    {
        sb.Append('{');
        bool first = true;
        object items = alist;
        while (Value.IsPair(items))
        {
            Pair entry = Value.AsPair(items);
            if (!Value.IsPair(entry.car))
                throw new SchemeError(pos, "json-write: object entry is not a pair: ~s", entry.car);
            Pair kv = Value.AsPair(entry.car);
            if (!Value.IsString(kv.car))
                throw new SchemeError(pos, "json-write: object key is not a string: ~s", kv.car);
            if (!first) sb.Append(',');
            first = false;
            WriteString(Value.AsString(kv.car), sb);
            sb.Append(':');
            Write(kv.cdr, sb, pos);
            items = entry.cdr;
        }
        sb.Append('}');
    }

    // Writes a JSON string literal (with surrounding quotes) into sb, applying
    // the same escaping as the original Scheme implementation: the named
    // escapes plus \uXXXX (4-digit lowercase hex) for control chars < 0x20.
    public static void WriteString(char[] s, StringBuilder sb)
    {
        sb.Append('"');
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                case '\b': sb.Append("\\b"); break;
                case '\f': sb.Append("\\f"); break;
                default:
                    if (c < 0x20)
                    {
                        sb.Append("\\u");
                        sb.Append(((int)c).ToString("x4"));
                    }
                    else
                    {
                        sb.Append(c);
                    }
                    break;
            }
        }
        sb.Append('"');
    }
}
