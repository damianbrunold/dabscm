package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableRefDefault extends Primitive {
    @Override
    public String name() { return "hash-table-ref/default"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-ref/default ht key default)\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns the value associated with key in ht, or default if key is not found.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 42)\n" +
               "  (hash-table-ref/default ht 'x 0) => 42\n" +
               "  (hash-table-ref/default ht 'y 0) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        Object result = ht.get(arguments[1]);
        return result != null ? result : arguments[2];
    }
}
