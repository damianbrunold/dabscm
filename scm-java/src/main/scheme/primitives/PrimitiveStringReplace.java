package scheme.primitives;

import scheme.*;

public class PrimitiveStringReplace extends Primitive {
    @Override
    public String name() {
        return "string-replace-all";
    }

    @Override
    public String info() {
        return "Syntax: (string-replace-all s pattern replacement)\n" +
               "Library: (scm string)\n" +
               "Description: Returns a new string with all occurrences of pattern in s replaced by replacement.\n" +
               "Example:\n" +
               "  (string-replace-all \"hello world\" \"world\" \"there\") => \"hello there\"\n" +
               "  (string-replace-all \"aabbcc\" \"b\" \"x\") => \"aaxxcc\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        var s = new String(Value.asString(arguments[0]));
        var what = new String(Value.asString(arguments[1]));
        var replace = new String(Value.asString(arguments[2]));
        return s.replace(what, replace).toCharArray();
    }
}
