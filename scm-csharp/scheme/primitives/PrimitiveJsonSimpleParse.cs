using System.Globalization;
using System.Numerics;
using System.Text;

namespace scheme;

public class PrimitiveJsonSimpleParse : Primitive
{
    public override string Name()
    {
        return "json-simple-parse";
    }

    public override string Info()
    {
        return
            "Syntax: (json-parse str)\n" +
            "Library: (scm json simple)\n" +
            "Description: Parses the JSON text in string str and returns its Scheme\n" +
            "  representation: objects as alists with string keys (order preserved),\n" +
            "  arrays as vectors, strings as strings, integral numbers as exact\n" +
            "  integers and fractional ones as inexact reals, true/false as #t/#f,\n" +
            "  and null as the symbol 'null. Raises an error on malformed input, as\n" +
               "  RFC 8259 defines it: also on text after the value, numbers with\n" +
               "  leading zeros and control characters in strings.\n" +
            "Example:\n" +
            "  (json-parse \"{\\\"a\\\": [1, 2.5, true, null]}\")\n" +
            "    => ((\"a\" . #(1 2.5 #t null)))";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var parser = new Parser(Value.AsString(arguments[0]), pos);
        object result = parser.ParseValue();
        parser.SkipWs();
        parser.End();
        return result;
    }

    private class Parser
    {
        private readonly char[] s;
        private int pos;
        private readonly SourcePos? srcpos;

        public Parser(char[] s, SourcePos? srcpos)
        {
            this.s = s;
            this.pos = 0;
            this.srcpos = srcpos;
        }

        private void Err(string msg)
        {
            throw new SchemeError(srcpos, "json: " + msg);
        }

        private int Peek()
        {
            return pos < s.Length ? s[pos] : -1;
        }

        private char Next()
        {
            if (pos >= s.Length) Err("unexpected end of input");
            return s[pos++];
        }

        // nothing but whitespace after the value (RFC 8259)
        public void End()
        {
            if (pos < s.Length) Err("unexpected trailing characters");
        }

        public void SkipWs()
        {
            while (pos < s.Length && char.IsWhiteSpace(s[pos])) pos++;
        }

        private void Expect(char ch)
        {
            SkipWs();
            if (Peek() == ch) pos++;
            else Err("expected " + ch);
        }

        public object ParseValue()
        {
            System.Runtime.CompilerServices.RuntimeHelpers.EnsureSufficientExecutionStack(); // deep nesting: an error, not a dead process
            SkipWs();
            int c = Peek();
            if (c == -1) Err("unexpected end of input");
            switch ((char)c)
            {
                case '{': return ParseObject();
                case '[': return ParseArray();
                case '"': return ParseString();
                case 't': return ParseLit("true", Value.T);
                case 'f': return ParseLit("false", Value.F);
                case 'n': return ParseLit("null", Value.Intern("null"));
                default:
                    if (c == '-' || (c >= '0' && c <= '9')) return ParseNumber();
                    Err("unexpected char " + (char)c);
                    return Value.NIL; // unreachable
            }
        }

        private object ParseLit(string word, object val)
        {
            foreach (char wc in word)
            {
                if (Peek() != wc) Err("expected " + word);
                pos++;
            }
            return val;
        }

        private object ParseObject()
        {
            pos++; // consume {
            SkipWs();
            if (Peek() == '}') { pos++; return Value.NIL; }
            var entries = new List<object>();
            while (true)
            {
                SkipWs();
                object key = ParseString();
                Expect(':');
                object val = ParseValue();
                entries.Add(new Pair(key, val));
                SkipWs();
                int c = Peek();
                if (c == ',') { pos++; continue; }
                if (c == '}') { pos++; break; }
                Err("expected , or }");
            }
            object result = Value.NIL;
            for (int i = entries.Count - 1; i >= 0; i--) result = new Pair(entries[i], result);
            return result;
        }

        private object ParseArray()
        {
            pos++; // consume [
            SkipWs();
            if (Peek() == ']') { pos++; return new object[0]; }
            var items = new List<object>();
            while (true)
            {
                items.Add(ParseValue());
                SkipWs();
                int c = Peek();
                if (c == ',') { pos++; continue; }
                if (c == ']') { pos++; break; }
                Err("expected , or ]");
            }
            return items.ToArray();
        }

        private object ParseString()
        {
            SkipWs();
            if (Peek() != '"') Err("expected string");
            pos++;
            var sb = new StringBuilder();
            while (true)
            {
                char c = Next();
                if (c == '"') return sb.ToString().ToCharArray();
                if (c == '\\')
                {
                    char e = Next();
                    switch (e)
                    {
                        case '"': sb.Append('"'); break;
                        case '\\': sb.Append('\\'); break;
                        case '/': sb.Append('/'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'u':
                            int cp = ParseHex4();
                            if (cp >= 0xD800 && cp <= 0xDBFF)
                            {
                                if (Next() != '\\') Err("expected low surrogate");
                                if (Next() != 'u') Err("expected \\u low surrogate");
                                int lo = ParseHex4();
                                if (lo < 0xDC00 || lo > 0xDFFF) Err("expected low surrogate");
                                // strings are UTF-16 here: the pair, as the
                                // reader makes for such a character
                                sb.Append((char)cp).Append((char)lo);
                            }
                            else
                            {
                                sb.Append((char)cp);
                            }
                            break;
                        default: Err("bad escape"); break;
                    }
                }
                else if (c < 0x20)
                {
                    Err("control character in string");
                }
                else
                {
                    sb.Append(c);
                }
            }
        }

        private int ParseHex4()
        {
            int acc = 0;
            for (int i = 0; i < 4; i++) acc = acc * 16 + HexDigit(Next());
            return acc;
        }

        private int HexDigit(char c)
        {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
            if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
            Err("bad hex digit");
            return 0; // unreachable
        }

        private object ParseNumber()
        {
            // RFC 8259: -?(0|[1-9][0-9]*)(.[0-9]+)?([eE][+-]?[0-9]+)?
            int start = pos;
            if (Peek() == '-') pos++;
            if (Peek() == '0')
            {
                pos++;
                if (Peek() >= '0' && Peek() <= '9') Err("leading zero in number");
            }
            else
            {
                if (!(Peek() >= '0' && Peek() <= '9')) Err("bad number");
                while (Peek() >= '0' && Peek() <= '9') pos++;
            }
            if (Peek() == '.')
            {
                pos++;
                if (!(Peek() >= '0' && Peek() <= '9')) Err("bad number");
                while (Peek() >= '0' && Peek() <= '9') pos++;
            }
            if (Peek() == 'e' || Peek() == 'E')
            {
                pos++;
                if (Peek() == '+' || Peek() == '-') pos++;
                if (!(Peek() >= '0' && Peek() <= '9')) Err("bad number");
                while (Peek() >= '0' && Peek() <= '9') pos++;
            }
            string num = new string(s, start, pos - start);
            // Mirror string->number for base-10 JSON numbers: an exact integer
            // when no '.', 'e' or 'E' is present, otherwise an inexact real.
            bool exact = num.IndexOf('.') == -1
                         && num.IndexOf('e') == -1
                         && num.IndexOf('E') == -1;
            if (exact)
            {
                if (long.TryParse(num, NumberStyles.Integer, CultureInfo.InvariantCulture, out long lv))
                    return lv;
                return BigInteger.Parse(num, CultureInfo.InvariantCulture);
            }
            return double.Parse(num, CultureInfo.InvariantCulture);
        }
    }
}
