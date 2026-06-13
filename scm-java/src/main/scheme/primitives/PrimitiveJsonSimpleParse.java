package scheme.primitives;

import scheme.*;

import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveJsonSimpleParse extends Primitive {
    @Override
    public String name() {
        return "json-simple-parse";
    }

    @Override
    public String info() {
        return "Syntax: (json-parse str)\n" +
               "Library: (scm json simple)\n" +
               "Description: Parses the JSON text in string str and returns its Scheme\n" +
               "  representation: objects as alists with string keys (order preserved),\n" +
               "  arrays as vectors, strings as strings, integral numbers as exact\n" +
               "  integers and fractional ones as inexact reals, true/false as #t/#f,\n" +
               "  and null as the symbol 'null. Raises an error on malformed input.\n" +
               "Example:\n" +
               "  (json-parse \"{\\\"a\\\": [1, 2.5, true, null]}\")\n" +
               "    => ((\"a\" . #(1 2.5 #t null)))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Parser parser = new Parser(Value.asString(arguments[0]), pos);
        Object result = parser.parseValue();
        parser.skipWs();
        return result;
    }

    private static class Parser {
        private final char[] s;
        private int pos;
        private final SourcePos srcpos;

        Parser(char[] s, SourcePos srcpos) {
            this.s = s;
            this.pos = 0;
            this.srcpos = srcpos;
        }

        private void err(String msg) {
            throw new SchemeError(srcpos, "json: " + msg);
        }

        private int peek() {
            return pos < s.length ? s[pos] : -1;
        }

        private char next() {
            if (pos >= s.length) err("unexpected end of input");
            return s[pos++];
        }

        void skipWs() {
            while (pos < s.length && Character.isWhitespace(s[pos])) pos++;
        }

        private void expect(char ch) {
            skipWs();
            if (peek() == ch) pos++;
            else err("expected " + ch);
        }

        Object parseValue() {
            skipWs();
            int c = peek();
            if (c == -1) err("unexpected end of input");
            switch ((char) c) {
                case '{': return parseObject();
                case '[': return parseArray();
                case '"': return parseString();
                case 't': return parseLit("true", Value.T);
                case 'f': return parseLit("false", Value.F);
                case 'n': return parseLit("null", Value.intern("null"));
                default:
                    if (c == '-' || (c >= '0' && c <= '9')) return parseNumber();
                    err("unexpected char " + (char) c);
                    return Value.NIL; // unreachable
            }
        }

        private Object parseLit(String word, Object val) {
            for (int i = 0; i < word.length(); i++) {
                if (peek() != word.charAt(i)) err("expected " + word);
                pos++;
            }
            return val;
        }

        private Object parseObject() {
            pos++; // consume {
            skipWs();
            if (peek() == '}') { pos++; return Value.NIL; }
            List<Object> entries = new ArrayList<>();
            while (true) {
                skipWs();
                Object key = parseString();
                expect(':');
                Object val = parseValue();
                entries.add(new Pair(key, val));
                skipWs();
                int c = peek();
                if (c == ',') { pos++; continue; }
                if (c == '}') { pos++; break; }
                err("expected , or }");
            }
            Object result = Value.NIL;
            for (int i = entries.size() - 1; i >= 0; i--) result = new Pair(entries.get(i), result);
            return result;
        }

        private Object parseArray() {
            pos++; // consume [
            skipWs();
            if (peek() == ']') { pos++; return new Object[0]; }
            List<Object> items = new ArrayList<>();
            while (true) {
                items.add(parseValue());
                skipWs();
                int c = peek();
                if (c == ',') { pos++; continue; }
                if (c == ']') { pos++; break; }
                err("expected , or ]");
            }
            return items.toArray();
        }

        private Object parseString() {
            skipWs();
            if (peek() != '"') err("expected string");
            pos++;
            StringBuilder sb = new StringBuilder();
            while (true) {
                char c = next();
                if (c == '"') return sb.toString().toCharArray();
                if (c == '\\') {
                    char e = next();
                    switch (e) {
                        case '"': sb.append('"'); break;
                        case '\\': sb.append('\\'); break;
                        case '/': sb.append('/'); break;
                        case 'b': sb.append('\b'); break;
                        case 'f': sb.append('\f'); break;
                        case 'n': sb.append('\n'); break;
                        case 'r': sb.append('\r'); break;
                        case 't': sb.append('\t'); break;
                        case 'u': {
                            int cp = parseHex4();
                            if (cp >= 0xD800 && cp <= 0xDBFF) {
                                if (next() != '\\') err("expected low surrogate");
                                if (next() != 'u') err("expected \\u low surrogate");
                                int lo = parseHex4();
                                int combined = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00);
                                // Scheme chars are 16-bit; match the original
                                // integer->char behaviour (truncates to 16 bits).
                                sb.append((char) combined);
                            } else {
                                sb.append((char) cp);
                            }
                            break;
                        }
                        default: err("bad escape"); break;
                    }
                } else {
                    sb.append(c);
                }
            }
        }

        private int parseHex4() {
            int acc = 0;
            for (int i = 0; i < 4; i++) acc = acc * 16 + hexDigit(next());
            return acc;
        }

        private int hexDigit(char c) {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
            if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
            err("bad hex digit");
            return 0; // unreachable
        }

        private Object parseNumber() {
            int start = pos;
            if (peek() == '-') pos++;
            while (peek() >= '0' && peek() <= '9') pos++;
            if (peek() == '.') {
                pos++;
                while (peek() >= '0' && peek() <= '9') pos++;
            }
            if (peek() == 'e' || peek() == 'E') {
                pos++;
                if (peek() == '+' || peek() == '-') pos++;
                while (peek() >= '0' && peek() <= '9') pos++;
            }
            String num = new String(s, start, pos - start);
            // Mirror string->number for base-10 JSON numbers: an exact integer
            // when no '.', 'e' or 'E' is present, otherwise an inexact real.
            boolean exact = num.indexOf('.') == -1
                            && num.indexOf('e') == -1
                            && num.indexOf('E') == -1;
            if (exact) {
                try {
                    return Long.parseLong(num);
                } catch (NumberFormatException ex) {
                    return new BigInteger(num);
                }
            }
            return Double.parseDouble(num);
        }
    }
}
