package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableP extends Primitive {
    @Override
    public String name() { return "hash-table?"; }

    @Override
    public String info() {
        return "Syntax: (hash-table? obj)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns #t if obj is a hash table, #f otherwise.\n" +
               "Example:\n" +
               "  (hash-table? (make-hash-table)) => #t\n" +
               "  (hash-table? '()) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return arguments[0] instanceof SchemeHashTable;
    }
}
