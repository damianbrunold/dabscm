namespace scheme;

class PrimitiveReadErrorP : Primitive {
    public override string Name() => "read-error?";
    public override string Info() =>
        "Syntax: (read-error? obj)\n" +
        "Library: (scheme read)\n" +
        "Description: Returns #t if obj is an object representing an error that occurred while reading, otherwise returns #f.\n" +
        "Example:\n" +
        "  (read-error? (guard (e (#t e)) (read (open-input-string \"(\")))) => #t";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        return args[0] is ReadErrorObject ? Value.T : Value.F;
    }
}
