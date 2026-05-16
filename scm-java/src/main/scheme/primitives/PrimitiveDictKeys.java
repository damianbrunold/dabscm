package scheme.primitives;

import scheme.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public class PrimitiveDictKeys extends Primitive {
    @Override
    public String name() {
        return "dict-keys";
    }

    @Override
    public String info() {
        return "Syntax: (dict-keys d)\n" +
               "Library: (scm core)\n" +
               "Description: Returns a list of all keys (as strings) in the dictionary d.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"a\" 1)\n" +
               "    (dict-put d \"b\" 2)\n" +
               "    (dict-keys d)) => (\"a\" \"b\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        HashMap<String, Object> dict = Value.asDict(arguments[0]);
        List<char[]> keys = new ArrayList<>();
        for (Object key : dict.keySet()) {
            keys.add(((String) key).toCharArray());
        }
        return Pair.list(keys.toArray());
    }
}
