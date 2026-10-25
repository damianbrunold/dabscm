namespace scheme;

// The Java JIT captures escape continuations for such receivers; the C# VM
// has no JIT and always captures full continuations.
class PrimitiveEscapeOnlyReceiverP : Primitive {
    public override string Name() => "%escape-only-receiver?";
    public override string Info()
    {
        return
            "Syntax: (%escape-only-receiver? proc)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if call/cc may capture an escape continuation for proc\n" +
            "  (a receiver that only calls its continuation within the call). Always #f\n" +
            "  in this implementation, which has no JIT.\n" +
            "Example:\n" +
            "  (%escape-only-receiver? (lambda (return) (return 1))) => #f";
    }
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        return Value.F;
    }
}
