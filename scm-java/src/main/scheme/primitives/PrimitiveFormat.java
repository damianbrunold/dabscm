package scheme.primitives;

import scheme.*;

import java.io.Writer;
import java.util.ArrayList;

public class PrimitiveFormat extends Primitive {
    private Modules modules;

    public PrimitiveFormat(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "format";
    }

    @Override
    public String info() {
        return "Syntax: (format dest fmt val ...)\n" +
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

    private static String helpText() {
        return
            "~a  display          ~s  write            ~w  write-shared\n" +
            "~d  decimal          ~x  hex              ~o  octal\n" +
            "~b  binary           ~c  character        ~y  pretty-print\n" +
            "~f  fixed-float      ~?  recursive        ~k  recursive (alias)\n" +
            "~%  newline          ~n  newline (alias)   ~&  freshline\n" +
            "~t  tab              ~_  space            ~~  tilde\n" +
            "~h  help\n";
    }

    private static final String[] PP_INDENT2_FORMS = {
        "begin", "define", "define-syntax", "define-record-type",
        "lambda", "let", "let*", "letrec", "letrec*", "let-values", "let*-values",
        "when", "unless", "do", "guard", "define-library"
    };

    private static boolean isPPIndent2(Object head) {
        if (Value.isSymbol(head)) {
            String name = head.toString();
            for (String f : PP_INDENT2_FORMS) {
                if (f.equals(name)) return true;
            }
        }
        return false;
    }

    private static void ppSpaces(int n, StringBuilder sb) {
        for (int i = 0; i < n; i++) sb.append(' ');
    }

    private static void ppExpr(Object expr, int indent, int lineWidth, StringBuilder sb) {
        if (!Value.isPair(expr) || expr == Value.NIL) {
            sb.append(Value.printRep(expr));
        } else {
            String s = Value.printRep(expr);
            if (indent + s.length() <= lineWidth) {
                sb.append(s);
            } else {
                ppList(expr, indent, lineWidth, sb);
            }
        }
    }

    private static void ppList(Object expr, int indent, int lineWidth, StringBuilder sb) {
        Pair pair = (Pair) expr;
        sb.append('(');
        Object head = pair.car;
        Object tail = pair.cdr;
        String headStr = Value.printRep(head);
        int headLen = headStr.length();
        boolean indent2 = isPPIndent2(head);
        int firstCol = indent + 1 + headLen + 1;
        int bodyInd = indent2 ? indent + 2 : firstCol;
        sb.append(headStr);
        if (tail == Value.NIL) {
            sb.append(')');
        } else if (Value.isPair(tail)) {
            sb.append(' ');
            Pair tailPair = (Pair) tail;
            ppExpr(tailPair.car, firstCol, lineWidth, sb);
            Object items = tailPair.cdr;
            while (true) {
                if (items == Value.NIL) {
                    sb.append(')');
                    break;
                } else if (Value.isPair(items)) {
                    sb.append('\n');
                    ppSpaces(bodyInd, sb);
                    Pair ip = (Pair) items;
                    ppExpr(ip.car, bodyInd, lineWidth, sb);
                    items = ip.cdr;
                } else {
                    sb.append(" . ");
                    sb.append(Value.printRep(items));
                    sb.append(')');
                    break;
                }
            }
        } else {
            sb.append(" . ");
            sb.append(Value.printRep(tail));
            sb.append(')');
        }
    }

    private static String prettyPrint(Object expr, int lineWidth) {
        StringBuilder sb = new StringBuilder();
        ppExpr(expr, 0, lineWidth, sb);
        return sb.toString();
    }

    private String fmt(String s, char alignment, int width) {
        if (s.length() >= width) return s;
        int pad = width - s.length();
        StringBuilder sb = new StringBuilder(width);
        if (alignment == '-') {
            sb.append(s);
            for (int i = 0; i < pad; i++) sb.append(' ');
        } else {
            for (int i = 0; i < pad; i++) sb.append(' ');
            sb.append(s);
        }
        return sb.toString();
    }

    private void checkFormatArg(SourcePos pos, Object[] arguments, int idx) {
        if (idx >= arguments.length) {
            throw new SchemeError(pos, "format: not enough arguments for format string");
        }
    }

    private String formatSignedRadix(Object value, int radix) {
        if (value instanceof Long) {
            long val = (long)(Long) value;
            if (val == 0) return "0";
            if (val > 0) return Long.toString(val, radix);
            return "-" + Long.toString(-val, radix);
        }
        java.math.BigInteger bi = (java.math.BigInteger) value;
        return bi.toString(radix);
    }

    private String formatString(SourcePos pos, String message, Object[] arguments, int idx) {
        var result = new StringBuilder();
        int start = 0;
        int len = message.length();

        while (start < len) {
            int p = message.indexOf('~', start);
            if (p == -1) {
                result.append(message, start, len);
                break;
            }
            if (p > start) {
                result.append(message, start, p);
            }
            p++;
            if (p >= len) {
                throw new SchemeError(pos, "format: unexpected end of format string after ~");
            }
            char alignment = '+';
            int width = 0;
            if (message.charAt(p) == '-') {
                alignment = '-';
                p++;
            }
            int widthStart = p;
            while (p < len && message.charAt(p) >= '0' && message.charAt(p) <= '9') {
                p++;
            }
            if (p > widthStart) {
                width = Integer.parseInt(message.substring(widthStart, p));
            }
            int precision = -1;
            if (p < len && message.charAt(p) == ',') {
                p++;
                int precStart = p;
                while (p < len && message.charAt(p) >= '0' && message.charAt(p) <= '9') {
                    p++;
                }
                if (p > precStart) {
                    precision = Integer.parseInt(message.substring(precStart, p));
                }
            }
            if (p >= len) {
                throw new SchemeError(pos, "format: unexpected end of format string after ~");
            }
            char type = message.charAt(p);
            switch (type) {
                case 'a':
                case 'A':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(Value.displayRep(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 's':
                case 'S':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(Value.printRep(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 'w':
                case 'W':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(Value.printRepShared(arguments[idx]), alignment, width));
                    idx++;
                    break;
                case 'y':
                case 'Y':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(prettyPrint(arguments[idx], width > 0 ? width : 79), alignment, width));
                    idx++;
                    break;
                case 'd':
                case 'D':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(formatSignedRadix(arguments[idx], 10), alignment, width));
                    idx++;
                    break;
                case 'x':
                case 'X':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(formatSignedRadix(arguments[idx], 16), alignment, width));
                    idx++;
                    break;
                case 'o':
                case 'O':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(formatSignedRadix(arguments[idx], 8), alignment, width));
                    idx++;
                    break;
                case 'b':
                case 'B':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(formatSignedRadix(arguments[idx], 2), alignment, width));
                    idx++;
                    break;
                case 'c':
                case 'C':
                    checkFormatArg(pos, arguments, idx);
                    result.append(fmt(String.valueOf(Value.asChar(arguments[idx])), alignment, width));
                    idx++;
                    break;
                case 'f':
                case 'F':
                    checkFormatArg(pos, arguments, idx);
                    double val = toReal(arguments[idx]);
                    int prec = precision >= 0 ? precision : 6;
                    String formatted = String.format(java.util.Locale.US, "%." + prec + "f", val);
                    result.append(fmt(formatted, alignment, width));
                    idx++;
                    break;
                case '?':
                case 'k':
                case 'K':
                    checkFormatArg(pos, arguments, idx);
                    checkFormatArg(pos, arguments, idx + 1);
                    String subFmt = new String(Value.asString(arguments[idx]));
                    var subArgs = new ArrayList<Object>();
                    Pair.appendToList(arguments[idx + 1], subArgs);
                    result.append(formatString(pos, subFmt, subArgs.toArray(), 0));
                    idx += 2;
                    break;
                case 'n':
                case 'N':
                    result.append('\n');
                    break;
                case '%':
                    result.append('\n');
                    break;
                case '&':
                    if (result.length() == 0 || result.charAt(result.length() - 1) != '\n') {
                        result.append('\n');
                    }
                    break;
                case 't':
                case 'T':
                    result.append('\t');
                    break;
                case '_':
                    result.append(' ');
                    break;
                case '~':
                    result.append('~');
                    break;
                case 'h':
                case 'H':
                    result.append(helpText());
                    break;
                default:
                    throw new SchemeError(pos, "format: unrecognized directive ~~~a", type);
            }
            start = p + 1;
        }
        return result.toString();
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        var dest = arguments[0];
        var message = new String(Value.asString(arguments[1]));
        var formatted = formatString(pos, message, arguments, 2);
        if (dest.equals(Value.F)) {
            return formatted.toCharArray();
        } else {
            Writer port;
            if (dest.equals(Value.T)) {
                port = Value.asOutputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*"));
            } else {
                port = Value.asOutputPort(arguments[0]);
            }
            try {
                var str = formatted.toCharArray();
                port.write(str);
                if (str != null && str.length > 0) {
                    if (str[str.length - 1] == '\n') port.flush();
                }
            } catch (Exception e) {
                throw new SchemeError(pos, name() + ": ~s", e.getMessage());
            }
        }
        return new Values();
    }
}
