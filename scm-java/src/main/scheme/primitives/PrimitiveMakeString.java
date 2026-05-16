package scheme.primitives;

import scheme.*;

public class PrimitiveMakeString extends Primitive {
    @Override
    public String name() {
        return "make-string";
    }

    @Override
    public String info() {
        return "Syntax: (make-string k) (make-string k char)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns a newly allocated mutable string of k characters. If char is given, all characters are initialized to char; otherwise they are spaces.\n" +
               "Example:\n" +
               "  (make-string 3 #\\x) => \"xxx\"\n" +
               "  (make-string 3) => \"   \"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        int n = IntegerMath.toInt(arguments[0]);
        char ch = ' ';
        if (arguments.length == 2) ch = Value.asChar(arguments[1]);
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < n; i++) {
            result.append(ch);
        }
        return result.toString().toCharArray();
    }
}
