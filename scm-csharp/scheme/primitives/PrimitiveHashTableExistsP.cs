namespace scheme;

public class PrimitiveHashTableExistsP : Primitive
{
    public override string Name() => "hash-table-exists?";

    public override string Info() =>
        "Syntax: (hash-table-exists? ht key)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns #t if key is associated with a value in ht, #f otherwise.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 42)\n" +
        "  (hash-table-exists? ht 'x) => #t\n" +
        "  (hash-table-exists? ht 'y) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-exists?: not a hash table");
        return ht.Contains(arguments[1]);
    }
}
