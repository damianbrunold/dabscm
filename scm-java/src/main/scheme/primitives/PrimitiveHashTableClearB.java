package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableClearB extends Primitive {
    @Override
    public String name() { return "hash-table-clear!"; }

    @Override
    public String info() {
        return "Syntax: (hash-table-clear! ht)\n" +
               "Library: (srfi 125)\n" +
               "Description: Removes all associations from the hash table ht.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table-clear! ht)\n" +
               "  (hash-table-size ht) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        ht.clear();
        return Value.NIL;
    }
}
