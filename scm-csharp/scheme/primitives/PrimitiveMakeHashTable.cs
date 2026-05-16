namespace scheme;

public class PrimitiveMakeHashTable : Primitive
{
    public override string Name() => "make-hash-table";

    public override string Info() =>
        "Syntax: (make-hash-table [equality-proc [hash-proc]])\n" +
        "Library: (srfi 69)\n" +
        "Description: Creates a new empty hash table. The optional equality-proc determines key comparison: eq?, eqv?, or equal? (default). The optional hash-proc is accepted but ignored.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table-ref ht 'a) => 1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 2);
        EqualityMode mode = EqualityMode.Equal;
        if (arguments.Length >= 1)
        {
            if (arguments[0] is PrimitiveEqP)
                mode = EqualityMode.Eq;
            else if (arguments[0] is PrimitiveEqvP)
                mode = EqualityMode.Eqv;
            else
                mode = EqualityMode.Equal;
        }
        return new SchemeHashTable(mode);
    }
}
