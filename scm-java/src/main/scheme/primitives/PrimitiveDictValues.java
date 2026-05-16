package scheme.primitives;

import scheme.*;

import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

public class PrimitiveDictValues extends Primitive {
    @Override
    public String name() {
        return "dict-values";
    }

    @Override
    public String info() {
        return "Syntax: (dict-values d)\n" +
               "Library: (scm core)\n" +
               "Description: Returns a list of all values in the dictionary d.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"a\" 1)\n" +
               "    (dict-values d)) => (1)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        HashMap<String, Object> dict = Value.asDict(arguments[0]);
        List<Object> values = new ArrayList<>();
        for (Object value : dict.values()) {
            values.add(value);
        }
        return Pair.list(values.toArray());
    }
}
