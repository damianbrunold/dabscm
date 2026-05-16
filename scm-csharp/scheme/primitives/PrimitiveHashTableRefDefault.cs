namespace scheme;

public class PrimitiveHashTableRefDefault : Primitive
{
    public override string Name() => "hash-table-ref/default";

    public override string Info() =>
        "Syntax: (hash-table-ref/default ht key default)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns the value associated with key in ht, or default if key is not found.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 42)\n" +
        "  (hash-table-ref/default ht 'x 0) => 42\n" +
        "  (hash-table-ref/default ht 'y 0) => 0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-ref/default: not a hash table");
        var result = ht.Get(arguments[1]);
        return result ?? arguments[2];
    }
}
