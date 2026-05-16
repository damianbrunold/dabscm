package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveDigitValue extends Primitive {
    @Override
    public String name() {
        return "digit-value";
    }

    @Override
    public String info() {
        return "Syntax: (digit-value char)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns the numeric value (0-9) of a Unicode decimal digit character, or #f if the character is not a decimal digit.\n" +
               "Example:\n" +
               "  (digit-value #\\3) => 3\n" +
               "  (digit-value #\\a) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        char c = Value.asChar(arguments[0]);
        int v = Character.getNumericValue(c);
        if (Character.isDigit(c) && v >= 0 && v <= 9) {
            return (long) v;
        }
        return Value.F;
    }
}
