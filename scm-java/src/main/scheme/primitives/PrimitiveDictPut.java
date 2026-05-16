package scheme.primitives;

import scheme.*;

import java.util.HashMap;

public class PrimitiveDictPut extends Primitive {
    @Override
    public String name() {
        return "dict-put";
    }

    @Override
    public String info() {
        return "Syntax: (dict-put d key value)\n" +
               "Library: (scm core)\n" +
               "Description: Associates key (a string or symbol) with value in the dictionary d. If the key already exists, the old value is replaced.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"x\" 42)\n" +
               "    (dict-get d \"x\")) => 42";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        HashMap<String, Object> dict = Value.asDict(arguments[0]);
        String key;
        if (Value.isString(arguments[1])) {
            key = new String(Value.asString(arguments[1]));
        } else if (Value.isSymbol(arguments[1])) {
            key = Value.asSymbol(arguments[1]);
        } else {
            throw new SchemeError(pos, name() + ": Key must be string or symbol");
        }
        dict.put(key, arguments[2]);
        return new Values();
    }
}
