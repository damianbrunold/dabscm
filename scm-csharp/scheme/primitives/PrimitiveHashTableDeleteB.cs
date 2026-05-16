namespace scheme;

public class PrimitiveHashTableDeleteB : Primitive
{
    public override string Name() => "hash-table-delete!";

    public override string Info() =>
        "Syntax: (hash-table-delete! ht key)\n" +
        "Library: (srfi 69)\n" +
        "Description: Removes the association for key from the hash table ht. Has no effect if key is not present.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 42)\n" +
        "  (hash-table-delete! ht 'x)\n" +
        "  (hash-table-exists? ht 'x) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-delete!: not a hash table");
        ht.Delete(arguments[1]);
        return Value.NIL;
    }
}
