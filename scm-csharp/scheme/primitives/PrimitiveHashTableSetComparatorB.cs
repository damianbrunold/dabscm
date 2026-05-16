namespace scheme;

public class PrimitiveHashTableSetComparatorB : Primitive
{
    public override string Name() => "%hash-table-set-comparator!";
    public override string Info() => "";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "%hash-table-set-comparator!: not a hash table");
        ht.Comparator = arguments[1];
        return Value.NIL;
    }
}
