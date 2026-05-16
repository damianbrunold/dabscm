package scheme.primitives;

import scheme.*;
import java.math.BigInteger;

public class PrimitiveStringToNumber extends Primitive {
    @Override
    public String name() {
        return "string->number";
    }

    @Override
    public String info() {
        return "Syntax: (string->number s radix?)\n" +
               "Library: (scheme base)\n" +
               "Description: Converts the string s to a number using the given radix (default 10). Returns #f if s cannot be parsed as a number.\n" +
               "Example:\n" +
               "  (string->number \"42\") => 42\n" +
               "  (string->number \"ff\" 16) => 255\n" +
               "  (string->number \"abc\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String s = new String(Value.asString(arguments[0]));
        boolean exact = s.indexOf('.') == -1;
        int base = 10;
        if (arguments.length == 2) base = IntegerMath.toInt(arguments[1]);
        while (s.startsWith("#")) {
            if (s.startsWith("#e")) {
                exact = true;
                s = s.substring(2);
            } else if (s.startsWith("#i")) {
                exact = false;
                s = s.substring(2);
            } else if (s.startsWith("#x")) {
                base = 16;
                s = s.substring(2);
            } else if (s.startsWith("#b")) {
                base = 2;
                s = s.substring(2);
            } else if (s.startsWith("#o")) {
                base = 8;
                s = s.substring(2);
            } else {
                break;
            }
        }
        if (exact && base == 10 && s.matches(".*[eEsSfFdDlL].*"))
            exact = false;
        // TODO: add complex number parsing (e.g. "1+2i", "3-4i")
        try {
            if (exact) {
                int slash = s.indexOf('/');
                if (slash >= 0) {
                    String ns = s.substring(0, slash), ds = s.substring(slash + 1);
                    Object n = parseIntegerInRadix(ns, base);
                    Object d = parseIntegerInRadix(ds, base);
                    return Rational.create(n, d);
                }
                return parseIntegerInRadix(s, base);
            } else {
                // Normalize R7RS exponent markers (s, f, d, l) to 'e'
                return Double.parseDouble(s.replaceAll("[sfdlSFDL]", "e"));
            }
        } catch (NumberFormatException e) {
            return Value.F;
        }
    }

    private static Object parseIntegerInRadix(String s, int base) {
        try {
            return Long.parseLong(s, base);
        } catch (NumberFormatException e) {
            return IntegerMath.normalize(new BigInteger(s, base));
        }
    }
}
