namespace scheme;

public class PrimitiveHashTableComparator : Primitive
{
    public override string Name() => "%hash-table-comparator";
    public override string Info() => "";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "%hash-table-comparator: not a hash table");
        return ht.Comparator ?? Value.F;
    }
}
