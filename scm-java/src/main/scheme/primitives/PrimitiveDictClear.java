package scheme.primitives;

import scheme.*;

public class PrimitiveDictClear extends Primitive {
    @Override
    public String name() {
        return "dict-clear";
    }

    @Override
    public String info() {
        return "Syntax: (dict-clear d)\n" +
               "Library: (scm core)\n" +
               "Description: Removes all key-value associations from the dictionary d, leaving it empty.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"key\" 1)\n" +
               "    (dict-clear d)\n" +
               "    (dict-size d)) => 0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Value.asDict(arguments[0]).clear();
        return new Values();
    }
}
