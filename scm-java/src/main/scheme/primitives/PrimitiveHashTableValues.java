package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableValues extends Primitive {
    @Override
    public String name() { return "hash-table-values"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-values ht)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns a list of all values in the hash table ht. The order is unspecified.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table-set! ht 'b 2)\n" +
               "  (list-sort < (hash-table-values ht)) => (1 2)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        Object result = Value.NIL;
        for (Object val : ht.getValues())
            result = new Pair(val, result);
        return result;
    }
}
