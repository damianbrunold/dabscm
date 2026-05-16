package scheme.primitives;

import scheme.Primitive;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveCharGreaterEqP extends Primitive {
    @Override
    public String name() {
        return "char>=?";
    }

    @Override
    public String info() {
        return "Syntax: (char>=? char1 char2 char3 ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if the character arguments are monotonically non-increasing.\n" +
               "Example:\n" +
               "  (char>=? #\\b #\\a) => #t\n" +
               "  (char>=? #\\a #\\a) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, -1);
        Object current = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            Object next = arguments[i];
            if (!(Value.asChar(current).charValue() >= Value.asChar(next).charValue())) return false;
            current = next;
        }
        return true;
    }
}
