package scheme.primitives;

import scheme.*;

public class PrimitiveMakeHashTable extends Primitive {
    @Override
    public String name() { return "make-hash-table"; }

    @Override
    public String info() {
        return "Syntax: (make-hash-table [equality-proc [hash-proc]])\n" +
               "Library: (srfi 69)\n" +
               "Description: Creates a new empty hash table. The optional equality-proc determines key comparison: eq?, eqv?, or equal? (default). The optional hash-proc is accepted but ignored.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table-ref ht 'a) => 1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 2);
        SchemeHashTable.EqualityMode mode = SchemeHashTable.EqualityMode.EQUAL;
        if (arguments.length >= 1) {
            if (arguments[0] instanceof PrimitiveEqP)
                mode = SchemeHashTable.EqualityMode.EQ;
            else if (arguments[0] instanceof PrimitiveEqvP)
                mode = SchemeHashTable.EqualityMode.EQV;
            else
                mode = SchemeHashTable.EqualityMode.EQUAL;
        }
        return new SchemeHashTable(mode);
    }
}
