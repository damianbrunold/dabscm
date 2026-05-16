package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableDeleteB extends Primitive {
    @Override
    public String name() { return "hash-table-delete!"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-delete! ht key)\n" +
               "Library: (srfi 69)\n" +
               "Description: Removes the association for key from the hash table ht. Has no effect if key is not present.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 42)\n" +
               "  (hash-table-delete! ht 'x)\n" +
               "  (hash-table-exists? ht 'x) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        ht.delete(arguments[1]);
        return Value.NIL;
    }
}
