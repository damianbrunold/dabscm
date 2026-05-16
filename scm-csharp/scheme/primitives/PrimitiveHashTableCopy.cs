namespace scheme;

public class PrimitiveHashTableCopy : Primitive
{
    public override string Name() => "hash-table-copy";

    public override string Info() =>
        "Syntax: (hash-table-copy ht)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns a copy of the hash table ht with the same equality mode and all the same key-value associations.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (define ht2 (hash-table-copy ht))\n" +
        "  (hash-table-ref ht2 'a) => 1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-copy: not a hash table");
        return ht.Copy();
    }
}
