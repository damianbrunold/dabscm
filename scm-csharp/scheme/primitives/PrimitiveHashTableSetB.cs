namespace scheme;

public class PrimitiveHashTableSetB : Primitive
{
    public override string Name() => "hash-table-set!";

    public override string Info() =>
        "Syntax: (hash-table-set! ht key value)\n" +
        "Library: (srfi 69)\n" +
        "Description: Associates key with value in the hash table ht. If the key already exists, its value is updated.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 42)\n" +
        "  (hash-table-ref ht 'x) => 42";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-set!: not a hash table");
        ht.Set(arguments[1], arguments[2]);
        return Value.NIL;
    }
}
