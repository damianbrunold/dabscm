package scheme.primitives;

import scheme.*;

public class PrimitiveStringCopy extends Primitive {
    @Override
    public String name() {
        return "string-copy";
    }

    @Override
    public String info() {
        return "Syntax: (string-copy s start? end?)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns a newly allocated copy of the string s. If start and end are given, only that substring is copied.\n" +
               "Example:\n" +
               "  (string-copy \"hello\") => \"hello\"\n" +
               "  (string-copy \"hello\" 1 3) => \"el\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        char[] s = Value.asString(arguments[0]);
        return new String(s).toCharArray();
    }
}
