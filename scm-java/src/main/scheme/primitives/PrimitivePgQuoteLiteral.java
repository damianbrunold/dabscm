package scheme.primitives;

import scheme.*;

public class PrimitivePgQuoteLiteral extends Primitive {
    @Override public String name() { return "pg-quote-literal"; }
    @Override public String info() {
        return "Syntax: (pg-quote-literal s)\n" +
               "Library: (scm database postgres)\n" +
               "Description: Returns s wrapped in single quotes with " +
               "internal single quotes doubled — the SQL standard " +
               "string-literal escape, safe under PostgreSQL's default " +
               "standard_conforming_strings=on (backslashes stay literal). " +
               "Use for any user-controlled string interpolated into SQL.\n" +
               "Example:\n" +
               "  (pg-quote-literal \"O'Brien\") => \"'O''Brien'\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        char[] s = Value.asString(arguments[0]);
        int n = s.length;
        int quotes = 0;
        for (int i = 0; i < n; i++) {
            if (s[i] == '\'') quotes++;
        }
        char[] result = new char[n + quotes + 2];
        int o = 0;
        result[o++] = '\'';
        for (int i = 0; i < n; i++) {
            char c = s[i];
            if (c == '\'') {
                result[o++] = '\'';
                result[o++] = '\'';
            } else {
                result[o++] = c;
            }
        }
        result[o++] = '\'';
        return result;
    }
}
