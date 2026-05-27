namespace scheme;

class PrimitiveFileErrorP : Primitive {
    public override string Name() => "file-error?";
    public override string Info() =>
        "Syntax: (file-error? obj)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if obj is a file error object (as raised by file operations), otherwise returns #f.\n" +
        "Example:\n" +
        "  (guard (e (#t (file-error? e)))\n" +
        "    (open-input-file \"nonexistent\")) => #t";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        return args[0] is FileErrorObject ? Value.T : Value.F;
    }
}
