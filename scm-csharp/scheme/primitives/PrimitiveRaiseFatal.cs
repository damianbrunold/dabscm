namespace scheme;

/// <summary>
/// %raise-fatal: raises a condition bypassing all Scheme exception handlers.
/// Used internally by the VM's default top-level error handler.
/// </summary>
class PrimitiveRaiseFatal : Primitive {
    public override string Name() => "%raise-fatal";
    public override string Info() =>
        "Syntax: (%raise-fatal condition)\n" +
        "Library: (scm core)\n" +
        "Description: Raises condition as a fatal error, bypassing all Scheme-level exception handlers. Used internally by the VM's default top-level error handler.\n" +
        "Example:\n" +
        "  (%raise-fatal (make-error-object \"fatal\" '()))";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        object condition = args[0];
        if (condition is ErrorObject eo) {
            throw new SchemeError(pos, eo);
        } else {
            throw new SchemeError(pos, new ErrorObject(Value.DisplayRep(condition), Array.Empty<object>()));
        }
    }
}
