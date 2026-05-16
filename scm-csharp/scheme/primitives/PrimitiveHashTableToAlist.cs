namespace scheme;

public class PrimitiveHashTableToAlist : Primitive
{
    public override string Name() => "hash-table->alist";

    public override string Info() =>
        "Syntax: (hash-table->alist ht)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns an association list of all key-value pairs in the hash table ht. The order is unspecified.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table->alist ht) => ((a . 1))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table->alist: not a hash table");
        return ht.ToAlist();
    }
}
