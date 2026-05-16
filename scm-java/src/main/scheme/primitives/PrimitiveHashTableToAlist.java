package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableToAlist extends Primitive {
    @Override
    public String name() { return "hash-table->alist"; }

    @Override
    public String info() {
        return "Syntax: (hash-table->alist ht)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns an association list of all key-value pairs in the hash table ht. The order is unspecified.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table->alist ht) => ((a . 1))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        return ht.toAlist();
    }
}
