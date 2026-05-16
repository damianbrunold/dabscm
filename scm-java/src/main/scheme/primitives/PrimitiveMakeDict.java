package scheme.primitives;

import scheme.*;

import java.util.LinkedHashMap;

public class PrimitiveMakeDict extends Primitive {
    @Override
    public String name() {
        return "make-dict";
    }

    @Override
    public String info() {
        return "Syntax: (make-dict)\n" +
               "Library: (scm core)\n" +
               "Description: Returns a new empty mutable dictionary (hash map) with string or symbol keys.\n" +
               "Example:\n" +
               "  (let ((d (make-dict)))\n" +
               "    (dict-put d \"key\" 42)\n" +
               "    (dict-get d \"key\")) => 42";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return new LinkedHashMap<String, Object>();
    }
}
