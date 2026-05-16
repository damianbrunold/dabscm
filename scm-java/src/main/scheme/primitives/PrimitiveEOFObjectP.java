package scheme.primitives;

import scheme.*;

public class PrimitiveEOFObjectP extends Primitive {
    @Override
    public String name() {
        return "eof-object?";
    }

    @Override
    public String info() {
        return "Syntax: (eof-object? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an end-of-file object, otherwise returns #f.\n" +
               "Example:\n" +
               "  (eof-object? (read (open-input-string \"\"))) => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isEOFObject(arguments[0]);
    }
}
