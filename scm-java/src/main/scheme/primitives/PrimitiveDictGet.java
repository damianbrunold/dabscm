package scheme.primitives;

import scheme.*;

import java.util.HashMap;

public class PrimitiveDictGet extends Primitive {
    @Override
    public String name() {
        return "dict-get";
    }

    @Override
    public String info() {
        return "Syntax: (dict-get d key) (dict-get d key default)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the value associated with key in the dictionary d. If the key is not found and a default is given, returns it; otherwise raises an error.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"x\" 42)\n" +
               "    (dict-get d \"x\")) => 42";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        HashMap<String, Object> dict = Value.asDict(arguments[0]);
        String key;
        if (Value.isString(arguments[1])) {
            key = new String(Value.asString(arguments[1]));
        } else if (Value.isSymbol(arguments[1])) {
            key = Value.asSymbol(arguments[1]);
        } else {
            throw new SchemeError(pos, name() + ": Key must be string or symbol");
        }
        if (arguments.length == 3 && !dict.containsKey(key)) {
            return arguments[2];
        }
        if (!dict.containsKey(key)) {
            throw new SchemeError(pos, name() + ": Key ~s not found", key);
        }
        return dict.get(key);
    }
}
