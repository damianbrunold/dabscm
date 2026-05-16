package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableKeys extends Primitive {
    @Override
    public String name() { return "hash-table-keys"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-keys ht)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns a list of all keys in the hash table ht. The order is unspecified.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table-set! ht 'b 2)\n" +
               "  (list-sort symbol<? (hash-table-keys ht)) => (a b)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        Object result = Value.NIL;
        for (Object key : ht.getKeys())
            result = new Pair(key, result);
        return result;
    }
}
