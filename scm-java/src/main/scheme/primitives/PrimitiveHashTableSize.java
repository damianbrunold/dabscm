package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableSize extends Primitive {
    @Override
    public String name() { return "hash-table-size"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-size ht)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns the number of associations in the hash table ht.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 1)\n" +
               "  (hash-table-set! ht 'y 2)\n" +
               "  (hash-table-size ht) => 2";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        return (long) ht.size();
    }
}
