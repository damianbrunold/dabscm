package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableExistsP extends Primitive {
    @Override
    public String name() { return "hash-table-exists?"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-exists? ht key)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns #t if key is associated with a value in ht, #f otherwise.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 42)\n" +
               "  (hash-table-exists? ht 'x) => #t\n" +
               "  (hash-table-exists? ht 'y) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        return ht.contains(arguments[1]);
    }
}
