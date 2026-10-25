namespace scheme;

class PrimitiveEscapeOnlyReceiverP : Primitive {
    public override string Name() => "%escape-only-receiver?";
    public override string Info()
    {
        return
            "Syntax: (%escape-only-receiver? proc)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if proc is a procedure of one parameter that only calls\n" +
            "  the parameter directly in its own body, so that a continuation passed to it\n" +
            "  can only be invoked within the dynamic extent of the call. call/cc then\n" +
            "  captures an escape continuation, which is cheaper with compiled code.\n" +
            "Example:\n" +
            "  (%escape-only-receiver? (lambda (return) (return 1))) => #t";
    }
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        return args[0] is Lambda f && Jit.EscapeOnly(f) ? Value.T : Value.F;
    }
}
