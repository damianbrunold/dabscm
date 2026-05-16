namespace scheme;

public class PrimitiveHashTableSize : Primitive
{
    public override string Name() => "hash-table-size";

    public override string Info() =>
        "Syntax: (hash-table-size ht)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns the number of associations in the hash table ht.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 1)\n" +
        "  (hash-table-set! ht 'y 2)\n" +
        "  (hash-table-size ht) => 2";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-size: not a hash table");
        return (long)ht.Size();
    }
}
