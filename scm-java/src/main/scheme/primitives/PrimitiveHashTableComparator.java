package scheme.primitives;

import scheme.*;

public class PrimitiveHashTableComparator extends Primitive {
    @Override
    public String name() { return "%hash-table-comparator"; }

    @Override
    public String info() { return ""; }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (!(arguments[0] instanceof SchemeHashTable))
            throw new SchemeError(pos, name() + ": not a hash table");
        SchemeHashTable ht = (SchemeHashTable) arguments[0];
        return ht.comparator != null ? ht.comparator : Value.F;
    }
}
