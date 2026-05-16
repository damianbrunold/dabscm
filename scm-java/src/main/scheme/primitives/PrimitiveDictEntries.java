package scheme.primitives;

import scheme.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public class PrimitiveDictEntries extends Primitive {
    @Override
    public String name() {
        return "dict-entries";
    }

    @Override
    public String info() {
        return "Syntax: (dict-entries d)\n" +
               "Library: (scm core)\n" +
               "Description: Returns a list of (key . value) pairs for all entries in the dictionary d.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"a\" 1)\n" +
               "    (dict-entries d)) => ((\"a\" . 1))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        HashMap<String, Object> dict = Value.asDict(arguments[0]);
        List<Object> entries = new ArrayList<>();
        for (String key : dict.keySet()) {
            entries.add(new Pair(key.toCharArray(), dict.get(key)));
        }
        return Pair.list(entries.toArray());
    }
}
