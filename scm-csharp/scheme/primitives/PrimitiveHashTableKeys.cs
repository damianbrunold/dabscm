namespace scheme;

public class PrimitiveHashTableKeys : Primitive
{
    public override string Name() => "hash-table-keys";

    public override string Info() =>
        "Syntax: (hash-table-keys ht)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns a list of all keys in the hash table ht. The order is unspecified.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table-set! ht 'b 2)\n" +
        "  (list-sort symbol<? (hash-table-keys ht)) => (a b)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-keys: not a hash table");
        object result = Value.NIL;
        foreach (var key in ht.GetKeys())
            result = new Pair(key, result);
        return result;
    }
}
