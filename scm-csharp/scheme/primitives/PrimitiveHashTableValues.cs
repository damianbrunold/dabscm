namespace scheme;

public class PrimitiveHashTableValues : Primitive
{
    public override string Name() => "hash-table-values";

    public override string Info() =>
        "Syntax: (hash-table-values ht)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns a list of all values in the hash table ht. The order is unspecified.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table-set! ht 'b 2)\n" +
        "  (list-sort < (hash-table-values ht)) => (1 2)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-values: not a hash table");
        object result = Value.NIL;
        foreach (var val in ht.GetValues())
            result = new Pair(val, result);
        return result;
    }
}
