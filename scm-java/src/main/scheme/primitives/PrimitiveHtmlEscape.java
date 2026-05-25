package scheme.primitives;

import scheme.*;

public class PrimitiveHtmlEscape extends Primitive {
    @Override public String name() { return "html-escape"; }

    @Override public String info() {
        return "Syntax: (html-escape s)\n" +
               "Library: (scm html)\n" +
               "Description: Escapes the five HTML metacharacters (&, <, >, \", ') in s so the result is safe to splice into HTML text content or attribute values.\n" +
               "Example:\n" +
               "  (html-escape \"a < b & c\") => \"a &lt; b &amp; c\"";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        char[] s = Value.asString(arguments[0]);
        int n = s.length;
        int needed = 0;
        for (int i = 0; i < n; i++) {
            char c = s[i];
            switch (c) {
                case '<': case '>':   needed += 4; break;
                case '&': case '\'':  needed += 5; break;
                case '"':             needed += 6; break;
                default:              needed += 1; break;
            }
        }
        if (needed == n) {
            return s;
        }
        char[] out = new char[needed];
        int j = 0;
        for (int i = 0; i < n; i++) {
            char c = s[i];
            switch (c) {
                case '<':  out[j++]='&'; out[j++]='l'; out[j++]='t'; out[j++]=';'; break;
                case '>':  out[j++]='&'; out[j++]='g'; out[j++]='t'; out[j++]=';'; break;
                case '&':  out[j++]='&'; out[j++]='a'; out[j++]='m'; out[j++]='p'; out[j++]=';'; break;
                case '"':  out[j++]='&'; out[j++]='q'; out[j++]='u'; out[j++]='o'; out[j++]='t'; out[j++]=';'; break;
                case '\'': out[j++]='&'; out[j++]='#'; out[j++]='3'; out[j++]='9'; out[j++]=';'; break;
                default:   out[j++] = c; break;
            }
        }
        return out;
    }
}
