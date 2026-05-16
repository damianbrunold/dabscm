package scheme.primitives;

import scheme.*;

public class PrimitiveStringToSymbol extends Primitive {
    @Override
    public String name() {
        return "string->symbol";
    }

    @Override
    public String info() {
        return "Syntax: (string->symbol s)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the interned symbol whose name is the string s. Two calls with equal strings return the same symbol.\n" +
               "Example:\n" +
               "  (string->symbol \"hello\") => hello\n" +
               "  (eq? (string->symbol \"foo\") (string->symbol \"foo\")) => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.intern(new String(Value.asString(arguments[0])));
    }
}
