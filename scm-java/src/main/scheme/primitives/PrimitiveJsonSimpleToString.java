package scheme.primitives;

import scheme.*;

public class PrimitiveJsonSimpleToString extends Primitive {
    @Override
    public String name() {
        return "json-simple->string";
    }

    @Override
    public String info() {
        return "Syntax: (json->string val)\n" +
               "Library: (scm json simple)\n" +
               "Description: Returns compact JSON text for val as a string (see json-write).\n" +
               "Example:\n" +
               "  (json->string #(1 2 3)) => \"[1,2,3]\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        StringBuilder sb = new StringBuilder();
        write(arguments[0], sb, pos);
        return sb.toString().toCharArray();
    }

    // Compact serialization of a JSON value, shared with the pretty writer.
    public static void write(Object val, StringBuilder sb, SourcePos pos) {
        if (Value.isBoolean(val)) { sb.append(Value.asBoolean(val) ? "true" : "false"); return; }
        if (Value.isString(val)) { writeString(Value.asString(val), sb); return; }
        if (Value.isInteger(val)) { sb.append(val.toString()); return; }
        if (Value.isReal(val)) { sb.append(Value.formatDouble(Value.asReal(val))); return; }
        if (Value.isRational(val)) { sb.append(Value.asRational(val).toString()); return; }
        if (Value.isComplex(val)) { sb.append(Value.asComplex(val).toString()); return; }
        if (Value.isVector(val)) {
            Object[] vec = Value.asVector(val);
            sb.append('[');
            for (int i = 0; i < vec.length; i++) {
                if (i > 0) sb.append(',');
                write(vec[i], sb, pos);
            }
            sb.append(']');
            return;
        }
        if (Value.isNil(val)) { sb.append("{}"); return; }
        if (Value.isPair(val)) { writeObject(val, sb, pos); return; }
        if (Value.isSymbol(val) && Value.asSymbol(val).equals("null")) { sb.append("null"); return; }
        throw new SchemeError(pos, "json-write: cannot serialize: ~s", val);
    }

    private static void writeObject(Object alist, StringBuilder sb, SourcePos pos) {
        sb.append('{');
        boolean first = true;
        Object items = alist;
        while (Value.isPair(items)) {
            Pair entry = Value.asPair(items);
            if (!Value.isPair(entry.car)) {
                throw new SchemeError(pos, "json-write: object entry is not a pair: ~s", entry.car);
            }
            Pair kv = Value.asPair(entry.car);
            if (!Value.isString(kv.car)) {
                throw new SchemeError(pos, "json-write: object key is not a string: ~s", kv.car);
            }
            if (!first) sb.append(',');
            first = false;
            writeString(Value.asString(kv.car), sb);
            sb.append(':');
            write(kv.cdr, sb, pos);
            items = entry.cdr;
        }
        sb.append('}');
    }

    // Writes a JSON string literal (with surrounding quotes) into sb, applying
    // the same escaping as the original Scheme implementation: the named
    // escapes plus a four-hex-digit lowercase unicode escape for control
    // chars < 0x20.
    public static void writeString(char[] s, StringBuilder sb) {
        sb.append('"');
        for (char c : s) {
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                default:
                    if (c < 0x20) {
                        sb.append("\\u");
                        sb.append(String.format("%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                    break;
            }
        }
        sb.append('"');
    }
}
