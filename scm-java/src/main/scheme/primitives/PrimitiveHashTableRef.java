package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableRef extends Primitive {
    @Override
    public String name() { return "hash-table-ref"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-ref ht key [default-thunk])\n" +
               "Library: (srfi 69)\n" +
               "Description: Returns the value associated with key in ht. If the key is not found and default-thunk is provided, calls it and returns the result; otherwise raises an error.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'x 42)\n" +
               "  (hash-table-ref ht 'x) => 42";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        Object result = ht.get(arguments[1]);
        if (result == null) {
            if (arguments.length == 3) {
                Object thunk = arguments[2];
                if (Value.isPrimitive(thunk))
                    return Value.asPrimitive(thunk).apply(pos, new Object[0]);
                throw new SchemeError(pos, name() + ": key not found");
            }
            throw new SchemeError(pos, name() + ": key not found in hash table");
        }
        return result;
    }
}
