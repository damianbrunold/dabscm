package scheme.primitives;

import scheme.*;

public class PrimitiveMakeHashTable extends Primitive {
    @Override
    public String name() { return "make-hash-table"; }

    @Override
    public String info() {
        return "Syntax: (make-hash-table [equivalence [hash arg ...]])\n" +
               "Library: (srfi 69)\n" +
               "Description: Creates a new empty hash table. equivalence is eq?, eqv? or equal? (default), or a mode symbol (eq eqv equal string-ci char-ci numeric) as (srfi 69) and (srfi 125) pass it for string-ci=?, char-ci=? and =. The hash function and further arguments are accepted and ignored: the table hashes consistently with its equivalence.\n" +
               "Example:\n" +
               "  (define ht (make-hash-table equal?))\n" +
               "  (hash-table-set! ht 'a 1)\n" +
               "  (hash-table-ref ht 'a) => 1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        SchemeHashTable.EqualityMode mode = SchemeHashTable.EqualityMode.EQUAL;
        if (arguments.length >= 1) {
            SchemeHashTable.EqualityMode m = SchemeHashTable.modeOfSymbol(arguments[0]);
            if (m != null)
                mode = m;
            else if (arguments[0] instanceof PrimitiveEqP)
                mode = SchemeHashTable.EqualityMode.EQ;
            else if (arguments[0] instanceof PrimitiveEqvP)
                mode = SchemeHashTable.EqualityMode.EQV;
            else
                mode = SchemeHashTable.EqualityMode.EQUAL;
        }
        return new SchemeHashTable(mode);
    }
}
