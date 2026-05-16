namespace scheme;

public class PrimitiveHashTableP : Primitive
{
    public override string Name() => "hash-table?";

    public override string Info() =>
        "Syntax: (hash-table? obj)\n" +
        "Library: (srfi 69)\n" +
        "Description: Returns #t if obj is a hash table, #f otherwise.\n" +
        "Example:\n" +
        "  (hash-table? (make-hash-table)) => #t\n" +
        "  (hash-table? '()) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] is SchemeHashTable;
    }
}
