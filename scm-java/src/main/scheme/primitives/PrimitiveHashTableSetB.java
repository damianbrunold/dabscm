package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableSetB extends Primitive {
    @Override
    public String name() { return "hash-table-set!"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-set! ht key value)\n" +
               "Library: (srfi 69)\n" +
               "Description: Associates key with value in the hash table ht. If the key already exists, its value is updated.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 42)\n" +
               "  (hash-table-ref ht 'x) => 42";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        ht.set(arguments[1], arguments[2]);
        return Value.NIL;
    }
}
