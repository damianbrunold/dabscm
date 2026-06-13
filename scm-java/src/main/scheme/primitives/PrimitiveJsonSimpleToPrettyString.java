package scheme.primitives;

import scheme.*;

public class PrimitiveJsonSimpleToPrettyString extends Primitive {
    @Override
    public String name() {
        return "json-simple->pretty-string";
    }

    @Override
    public String info() {
        return "Syntax: (json->pretty-string val)\n" +
               "Library: (scm json simple)\n" +
               "Description: Returns two-space-indented JSON text for val as a string\n" +
               "  (see json-write-pretty).\n" +
               "Example:\n" +
               "  (json->pretty-string '((\"a\" . 1))) => \"{\\n  \\\"a\\\": 1\\n}\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        StringBuilder sb = new StringBuilder();
        go(arguments[0], 0, sb, pos);
        return sb.toString().toCharArray();
    }

    private static void indent(StringBuilder sb, int n) {
        for (int i = 0; i < 2 * n; i++) sb.append(' ');
    }

    private static void go(Object val, int depth, StringBuilder sb, SourcePos pos) {
        if (Value.isVector(val)) {
            Object[] vec = Value.asVector(val);
            int n = vec.length;
            if (n == 0) { sb.append("[]"); return; }
            sb.append("[\n");
            for (int i = 0; i < n; i++) {
                indent(sb, depth + 1);
                go(vec[i], depth + 1, sb, pos);
                if (i < n - 1) sb.append(',');
                sb.append('\n');
            }
            indent(sb, depth);
            sb.append(']');
            return;
        }
        if (Value.isNil(val)) { sb.append("{}"); return; }
        if (Value.isPair(val)) {
            sb.append("{\n");
            Object items = val;
            while (Value.isPair(items)) {
                Pair entry = Value.asPair(items);
                if (!Value.isPair(entry.car)) {
                    throw new SchemeError(pos, "json-write: object entry is not a pair: ~s", entry.car);
                }
                Pair kv = Value.asPair(entry.car);
                if (!Value.isString(kv.car)) {
                    throw new SchemeError(pos, "json-write: object key is not a string: ~s", kv.car);
                }
                indent(sb, depth + 1);
                PrimitiveJsonSimpleToString.writeString(Value.asString(kv.car), sb);
                sb.append(": ");
                go(kv.cdr, depth + 1, sb, pos);
                if (Value.isPair(entry.cdr)) sb.append(',');
                sb.append('\n');
                items = entry.cdr;
            }
            indent(sb, depth);
            sb.append('}');
            return;
        }
        // Scalars use the compact writer, matching the original implementation.
        PrimitiveJsonSimpleToString.write(val, sb, pos);
    }
}
