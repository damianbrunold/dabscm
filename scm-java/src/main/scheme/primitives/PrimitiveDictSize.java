package scheme.primitives;

import scheme.*;

public class PrimitiveDictSize extends Primitive {
    @Override
    public String name() {
        return "dict-size";
    }

    @Override
    public String info() {
        return "Syntax: (dict-size d)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the number of key-value entries in the dictionary d.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"a\" 1)\n" +
               "    (dict-size d)) => 1";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (long) Value.asDict(arguments[0]).size();
    }
}
