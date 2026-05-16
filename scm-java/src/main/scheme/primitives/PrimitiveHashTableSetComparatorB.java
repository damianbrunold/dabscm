package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableSetComparatorB extends Primitive {
    @Override
    public String name() { return "%hash-table-set-comparator!"; }

    @Override
    public String info() { return ""; }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        ht.comparator = arguments[1];
        return Value.NIL;
    }
}
