namespace scheme;

public class PrimitiveHashTableRef : Primitive
{
    public override string Name() => "hash-table-ref";

    public override string Info() =>
        "Syntax: (hash-table-ref ht key [default-thunk])\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns the value associated with key in ht. If the key is not found and default-thunk is provided, calls it and returns the result; otherwise raises an error.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'x 42)\n" +
        "  (hash-table-ref ht 'x) => 42";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        if (arguments[0] is not SchemeHashTable ht)
            throw new SchemeError(pos, "hash-table-ref: not a hash table");
        var result = ht.Get(arguments[1]);
        if (result == null)
        {
            if (arguments.Length == 3)
            {
                // Call the default thunk
                var thunk = arguments[2];
                if (Value.IsPrimitive(thunk))
                    return Value.AsPrimitive(thunk).Apply(pos, Array.Empty<object>());
                throw new SchemeError(pos, "hash-table-ref: key not found");
            }
            throw new SchemeError(pos, "hash-table-ref: key not found in hash table");
        }
        return result;
    }
}
