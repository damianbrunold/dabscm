using System.Collections.Generic;
using System.Text;

namespace scheme;

public class PrimitiveFormat : Primitive
{
    private Modules modules;

    public PrimitiveFormat(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "format";
    }

    public override string Info()
    {
        return
            "Syntax: (format dest fmt val ...)\n" +
            "Library: (scm io), (srfi 28), (srfi 48)\n" +
            "Description: Formats a string by substituting values for format\n" +
            "  directives in fmt.\n" +
            "  ~a  display (without quotes)\n" +
            "  ~s  write (with quotes)\n" +
            "  ~w  write with shared structure (datum labels)\n" +
            "  ~d  decimal integer\n" +
            "  ~x  hexadecimal integer (lowercase, signed)\n" +
            "  ~o  octal integer (signed)\n" +
            "  ~b  binary integer (signed)\n" +
            "  ~c  character\n" +
            "  ~y  pretty-print\n" +
            "  ~f  fixed-point float (~W,Df for width W and D decimal places)\n" +
            "  ~?  recursive format (takes format-string and arg-list)\n" +
            "  ~k  recursive format (alias for ~?)\n" +
            "  ~%  newline\n" +
            "  ~n  newline (alias)\n" +
            "  ~&  freshline (newline if not at start of line)\n" +
            "  ~t  tab\n" +
            "  ~_  space\n" +
            "  ~~  literal tilde\n" +
            "  ~h  help (display directive summary)\n" +
            "  Width/alignment: ~10a (right-align in 10), ~-10a (left-align).\n" +
            "  dest: #f (return string), #t (current output port), or a port.\n" +
            "Example:\n" +
            "  (format #f \"~a + ~a = ~a\" 1 2 3) => \"1 + 2 = 3\"\n" +
            "  (format #f \"~d in hex is ~x\" 255 255) => \"255 in hex is ff\"";
    }

    private static string HelpText()
    {
        return
            "~a  display          ~s  write            ~w  write-shared\n" +
            "~d  decimal          ~x  hex              ~o  octal\n" +
            "~b  binary           ~c  character        ~y  pretty-print\n" +
            "~f  fixed-float      ~?  recursive        ~k  recursive (alias)\n" +
            "~%  newline          ~n  newline (alias)   ~&  freshline\n" +
            "~t  tab              ~_  space            ~~  tilde\n" +
            "~h  help\n";
    }

    private static void PPSpaces(int n, StringBuilder sb)
    {
        for (int i = 0; i < n; i++) sb.Append(' ');
    }

    private static readonly string[] PPIndent2Forms = {
        "begin", "define", "define-syntax", "define-record-type",
        "lambda", "let", "let*", "letrec", "letrec*", "let-values", "let*-values",
        "when", "unless", "do", "guard", "define-library"
    };

    private static bool IsPPIndent2(object head)
    {
        if (Value.IsSymbol(head))
        {
            foreach (var f in PPIndent2Forms)
            {
                if (f == head.ToString()) return true;
            }
        }
        return false;
    }

    private static void PPExpr(object expr, int indent, int lineWidth, StringBuilder sb)
    {
        if (!Value.IsPair(expr) || expr == Value.NIL)
        {
            sb.Append(Value.PrintRep(expr));
        }
        else
        {
            string s = Value.PrintRep(expr);
            if (indent + s.Length <= lineWidth)
            {
                sb.Append(s);
            }
            else
            {
                PPList(expr, indent, lineWidth, sb);
            }
        }
    }

    private static void PPList(object expr, int indent, int lineWidth, StringBuilder sb)
    {
        var pair = (Pair)expr;
        sb.Append('(');
        object head = pair.car;
        object tail = pair.cdr;
        string headStr = Value.PrintRep(head);
        int headLen = headStr.Length;
        bool indent2 = IsPPIndent2(head);
        int firstCol = indent + 1 + headLen + 1;
        int bodyInd = indent2 ? indent + 2 : firstCol;
        sb.Append(headStr);
        if (tail == Value.NIL)
        {
            sb.Append(')');
        }
        else if (Value.IsPair(tail))
        {
            sb.Append(' ');
            var tailPair = (Pair)tail;
            PPExpr(tailPair.car, firstCol, lineWidth, sb);
            object items = tailPair.cdr;
            while (true)
            {
                if (items == Value.NIL)
                {
                    sb.Append(')');
                    break;
                }
                else if (Value.IsPair(items))
                {
                    sb.Append('\n');
                    PPSpaces(bodyInd, sb);
                    var ip = (Pair)items;
                    PPExpr(ip.car, bodyInd, lineWidth, sb);
                    items = ip.cdr;
                }
                else
                {
                    sb.Append(" . ");
                    sb.Append(Value.PrintRep(items));
                    sb.Append(')');
                    break;
                }
            }
        }
        else
        {
            sb.Append(" . ");
            sb.Append(Value.PrintRep(tail));
            sb.Append(')');
        }
    }

    private static string PrettyPrint(object expr, int lineWidth)
    {
        var sb = new StringBuilder();
        PPExpr(expr, 0, lineWidth, sb);
        return sb.ToString();
    }

    private string Fmt(string s, char alignment, int width)
    {
        if (s.Length >= width) return s;
        int pad = width - s.Length;
        if (alignment == '-')
        {
            return s + new string(' ', pad);
        }
        else
        {
            return new string(' ', pad) + s;
        }
    }

    private void CheckFormatArg(SourcePos? pos, object[] arguments, int idx)
    {
        if (idx >= arguments.Length)
        {
            throw new SchemeError(pos, "format: not enough arguments for format string");
        }
    }

    private string FormatSignedRadix(object val, int radix)
    {
        if (val is long lv)
        {
            if (lv == 0) return "0";
            if (lv > 0) return System.Convert.ToString(lv, radix);
            return "-" + System.Convert.ToString(-lv, radix);
        }
        var bv = IntegerMath.ToBigInteger(val);
        if (bv.IsZero) return "0";
        if (radix == 16) return bv < 0 ? "-" + (-bv).ToString("x") : bv.ToString("x");
        // For other radixes, convert via PrimitiveNumberToString-style logic
        bool negative = bv < 0;
        if (negative) bv = -bv;
        const string digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var chars = new System.Collections.Generic.List<char>();
        while (bv > 0)
        {
            System.Numerics.BigInteger rem;
            bv = System.Numerics.BigInteger.DivRem(bv, radix, out rem);
            chars.Add(digits[(int)rem]);
        }
        if (negative) chars.Add('-');
        chars.Reverse();
        return new string(chars.ToArray());
    }

    private string FormatString(SourcePos? pos, string message, object[] arguments, int idx)
    {
        var result = new StringBuilder();
        int start = 0;
        int len = message.Length;

        while (start < len)
        {
            int p = message.IndexOf('~', start);
            if (p == -1)
            {
                result.Append(message, start, len - start);
                break;
            }
            if (p > start)
            {
                result.Append(message, start, p - start);
            }
            p++;
            if (p >= len)
            {
                throw new SchemeError(pos, "format: unexpected end of format string after ~");
            }
            var alignment = '+';
            var width = 0;
            if (message[p] == '-')
            {
                alignment = '-';
                p++;
            }
            int widthStart = p;
            while (p < len && message[p] >= '0' && message[p] <= '9')
            {
                p++;
            }
            if (p > widthStart)
            {
                width = int.Parse(message.Substring(widthStart, p - widthStart));
            }
            int precision = -1;
            if (p < len && message[p] == ',')
            {
                p++;
                int precStart = p;
                while (p < len && message[p] >= '0' && message[p] <= '9')
                {
                    p++;
                }
                if (p > precStart)
                {
                    precision = int.Parse(message.Substring(precStart, p - precStart));
                }
            }
            if (p >= len)
            {
                throw new SchemeError(pos, "format: unexpected end of format string after ~");
            }
            char type = message[p];
            switch (type)
            {
                case 'a':
                case 'A':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(Value.DisplayRep(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 's':
                case 'S':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(Value.PrintRep(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 'w':
                case 'W':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(Value.PrintRepShared(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 'y':
                case 'Y':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(PrettyPrint(arguments[idx], width > 0 ? width : 79), alignment, width));
                    idx++;
                    break;
                case 'd':
                case 'D':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(FormatSignedRadix(arguments[idx], 10), alignment, width));
                    idx++;
                    break;
                case 'x':
                case 'X':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(FormatSignedRadix(arguments[idx], 16), alignment, width));
                    idx++;
                    break;
                case 'o':
                case 'O':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(FormatSignedRadix(arguments[idx], 8), alignment, width));
                    idx++;
                    break;
                case 'b':
                case 'B':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(FormatSignedRadix(arguments[idx], 2), alignment, width));
                    idx++;
                    break;
                case 'c':
                case 'C':
                    CheckFormatArg(pos, arguments, idx);
                    result.Append(Fmt(Value.AsChar(arguments[idx]).ToString(), alignment, width));
                    idx++;
                    break;
                case 'f':
                case 'F':
                    CheckFormatArg(pos, arguments, idx);
                    double val = ToReal(arguments[idx]);
                    int prec = precision >= 0 ? precision : 6;
                    string formatted = val.ToString("F" + prec, System.Globalization.CultureInfo.InvariantCulture);
                    result.Append(Fmt(formatted, alignment, width));
                    idx++;
                    break;
                case '?':
                case 'k':
                case 'K':
                    CheckFormatArg(pos, arguments, idx);
                    CheckFormatArg(pos, arguments, idx + 1);
                    string subFmt = new string(Value.AsString(arguments[idx]));
                    var subArgs = new List<object>();
                    Pair.AppendToList(arguments[idx + 1], subArgs);
                    result.Append(FormatString(pos, subFmt, subArgs.ToArray(), 0));
                    idx += 2;
                    break;
                case 'n':
                case 'N':
                    result.Append('\n');
                    break;
                case '%':
                    result.Append('\n');
                    break;
                case '&':
                    if (result.Length == 0 || result[result.Length - 1] != '\n')
                    {
                        result.Append('\n');
                    }
                    break;
                case 't':
                case 'T':
                    result.Append('\t');
                    break;
                case '_':
                    result.Append(' ');
                    break;
                case '~':
                    result.Append('~');
                    break;
                case 'h':
                case 'H':
                    result.Append(HelpText());
                    break;
                default:
                    throw new SchemeError(pos, "format: unrecognized directive ~~~a", type);
            }
            start = p + 1;
        }
        return result.ToString();
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        var dest = arguments[0];
        var message = new string(Value.AsString(arguments[1]));
        var formatted = FormatString(pos, message, arguments, 2);
        if (dest.Equals(Value.F))
        {
            return formatted.ToCharArray();
        }
        else
        {
            System.IO.TextWriter port;
            if (dest.Equals(Value.T))
            {
                var scmcore = modules.GetModuleRequired(pos, "scm core");
                port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
            }
            else
            {
                port = Value.AsOutputPort(arguments[0]);
            }
            try
            {
                var str = formatted.ToCharArray();
                port.Write(str);
                if (str != null && str.Length > 0)
                {
                    if (str[str.Length - 1] == '\n') port.Flush();
                }
            }
            catch (System.Exception e)
            {
                throw new SchemeError(pos, Name() + ": ~s", e.Message);
            }
        }
        return new Values();
    }
}
