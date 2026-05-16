package scheme.primitives;

import scheme.*;

public class PrimitiveStringContains extends Primitive {
    @Override
    public String name() {
        return "string-contains";
    }

    @Override
    public String info() {
        return "Syntax: (string-contains s1 s2 [start1 [end1 [start2 [end2]]]])\n" +
               "Library: (srfi 13)\n" +
               "Description: Returns the index of the first occurrence of s2[start2..end2) in s1[start1..end1), or #f if not found.\n" +
               "Example:\n" +
               "  (string-contains \"hello world\" \"world\") => 6\n" +
               "  (string-contains \"hello\" \"xyz\") => #f\n" +
               "  (string-contains \"abcabc\" \"b\" 2) => 4";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 6);
        var s = new String(Value.asString(arguments[0]));
        var what = new String(Value.asString(arguments[1]));
        var start1 = 0;
        var end1 = s.length();
        var start2 = 0;
        var end2 = what.length();
        if (arguments.length >= 3) {
            start1 = IntegerMath.toInt(arguments[2]);
            if (start1 < 0) start1 = s.length() + start1;
        }
        if (arguments.length >= 4)
            end1 = IntegerMath.toInt(arguments[3]);
        if (arguments.length >= 5)
            start2 = IntegerMath.toInt(arguments[4]);
        if (arguments.length >= 6)
            end2 = IntegerMath.toInt(arguments[5]);
        var region = s.substring(start1, end1);
        var pattern = what.substring(start2, end2);
        var idx = region.indexOf(pattern);
        if (idx == -1) return Value.F;
        return (long) (idx + start1);
    }
}
