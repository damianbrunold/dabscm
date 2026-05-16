namespace scheme;

public class PrimitiveHashTableClearB : Primitive
{
    public override string Name() => "hash-table-clear!";

    public override string Info() =>
        "Syntax: (hash-table-clear! ht)\n" +
        "Library: (srfi 125)\n" +
        "Description: Removes all associations from the hash table ht.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table-clear! ht)\n" +
        "  (hash-table-size ht) => 0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-clear!: not a hash table");
        ht.Clear();
        return Value.NIL;
    }
}
