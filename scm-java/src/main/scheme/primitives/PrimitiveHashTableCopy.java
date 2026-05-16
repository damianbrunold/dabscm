package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableCopy extends Primitive {
    @Override
    public String name() { return "hash-table-copy"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-copy ht)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns a copy of the hash table ht with the same equality mode and all the same key-value associations.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (define ht2 (hash-table-copy ht))\n" +
               "  (hash-table-ref ht2 'a) => 1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        return ht.copy();
    }
}
