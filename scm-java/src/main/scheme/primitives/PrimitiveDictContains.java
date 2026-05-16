package scheme.primitives;

import scheme.*;

public class PrimitiveDictContains extends Primitive {
    @Override
    public String name() {
        return "dict-contains";
    }

    @Override
    public String info() {
        return "Syntax: (dict-contains d key)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if the dictionary d contains an entry for key (a string or symbol), otherwise returns #f.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"x\" 42)\n" +
               "    (dict-contains d \"x\")) => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var dict = Value.asDict(arguments[0]);
        String key;
        if (Value.isString(arguments[1])) {
            key = new String(Value.asString(arguments[1]));
        } else if (Value.isSymbol(arguments[1])) {
            key = Value.asSymbol(arguments[1]);
        } else {
            throw new SchemeError(pos, name() + ": Key must be string or symbol");
        }
        return dict.containsKey(key);
    }
}
