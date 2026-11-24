package scheme.primitives;

import scheme.*;

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
        int radix = 10;
        if (arguments.length == 2) {
            radix = IntegerMath.toInt(arguments[1]);
            if (radix != 2 && radix != 8 && radix != 10 && radix != 16)
                throw new SchemeError(pos, "string->number: bad radix", arguments[1]);
        }
        return parse(s, radix);
    }

    /**
     * The number s denotes as the reader reads it (prefixes, rationals,
     * decimals, complex numbers), else #f: the whole string, without
     * surrounding whitespace. radix applies unless s has a radix prefix.
     */
    public static Object parse(String s, int radix) {
        if (s.isEmpty() || Character.isWhitespace(s.charAt(0))) return Value.F;
        boolean radixPrefix = false;
        int i = 0;
        while (i + 1 < s.length() && s.charAt(i) == '#') {
            char p = Character.toLowerCase(s.charAt(i + 1));
            if (p == 'x' || p == 'b' || p == 'o' || p == 'd') radixPrefix = true;
            else if (p != 'e' && p != 'i') return Value.F;
            i += 2;
        }
        String text = s;
        if (!radixPrefix && radix != 10)
            text = (radix == 16 ? "#x" : radix == 8 ? "#o" : "#b") + s;
        try {
            TextStream in = new TextStream(new java.io.PushbackReader(new java.io.StringReader(text), 16), "string->number");
            Token token = Tokenizer.readToken(in);
            if (token == null || in.peek() != -1) return Value.F;
            Object n = PrimitiveRead.numberFromToken(token);
            return n != null ? n : Value.F;
        } catch (java.io.IOException | RuntimeException e) {
            return Value.F;
        }
    }
}
