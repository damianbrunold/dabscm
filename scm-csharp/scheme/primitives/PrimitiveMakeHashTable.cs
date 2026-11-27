namespace scheme;

public class PrimitiveMakeHashTable : Primitive
{
    public override string Name() => "make-hash-table";

    public override string Info() =>
        "Syntax: (make-hash-table [equivalence [hash arg ...]])\n" +
        "Library: (srfi 69)\n" +
        "Description: Creates a new empty hash table. equivalence is eq?, eqv? or equal? (default), or a mode symbol (eq eqv equal string-ci char-ci numeric) as (srfi 69) and (srfi 125) pass it for string-ci=?, char-ci=? and =. The hash function and further arguments are accepted and ignored: the table hashes consistently with its equivalence.\n" +
        "Example:\n" +
        "  (define ht (make-hash-table equal?))\n" +
        "  (hash-table-set! ht 'a 1)\n" +
        "  (hash-table-ref ht 'a) => 1";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        EqualityMode mode = EqualityMode.Equal;
        if (arguments.Length >= 1)
        {
            EqualityMode? m = SchemeHashTable.ModeOfSymbol(arguments[0]);
            if (m != null)
                mode = m.Value;
            else if (arguments[0] is PrimitiveEqP)
                mode = EqualityMode.Eq;
            else if (arguments[0] is PrimitiveEqvP)
                mode = EqualityMode.Eqv;
            else
                mode = EqualityMode.Equal;
        }
        return new SchemeHashTable(mode);
    }
}
