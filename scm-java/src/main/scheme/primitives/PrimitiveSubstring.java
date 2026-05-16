package scheme.primitives;

import scheme.*;

public class PrimitiveSubstring extends Primitive {
    @Override
    public String name() {
        return "substring";
    }

    @Override
    public String info() {
        return "Syntax: (substring s start end)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated string containing the characters of s from index start (inclusive) to end (exclusive).\n" +
               "Example:\n" +
               "  (substring \"hello\" 1 3) => \"el\"\n" +
               "  (substring \"hello\" 0 5) => \"hello\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        char[] s = Value.asString(arguments[0]);
        int start = 0;
        int end = s.length;
        if (arguments.length > 1) {
            start = IntegerMath.toInt(arguments[1]);
            if (start < 0) start = s.length + start;
        }
        if (arguments.length > 2) {
            end = IntegerMath.toInt(arguments[2]);
            if (end < 0) end = s.length + end;
        }
        char[] result = new char[end - start];
        for (var i = 0; i < result.length; i++) {
            result[i] = s[start + i];
        }
        return result;
    }
}
