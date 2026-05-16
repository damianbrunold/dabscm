package scheme.primitives;

import scheme.*;

public class PrimitiveStringSetB extends Primitive {
    @Override
    public String name() {
        return "string-set!";
    }

    @Override
    public String info() {
        return "Syntax: (string-set! s k char)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Stores char in position k of the string s, mutating the string in place. It is an error if k is out of range.\n" +
               "Example:\n" +
               "  (let ((s (string-copy \"hello\")))\n" +
               "    (string-set! s 0 #\\H)\n" +
               "    s) => \"Hello\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        char[] s = Value.asString(arguments[0]);
        s[(int) (long) arguments[1]] = Value.asChar(arguments[2]);
        return new Values();
    }
}
