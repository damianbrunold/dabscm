namespace scheme;

class PrimitiveExceptionHandlersSet : Primitive {
    public override string Name() => "%exception-handlers-set!";
    public override string Info() =>
        "Syntax: (%exception-handlers-set! handlers)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Sets the current VM's exception handler stack to handlers.\n" +
        "Example:\n" +
        "  (%exception-handlers-set! '())";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 1, 1);
        if (VM.Current != null) VM.Current.exceptionHandlers = args[0];
        return Value.NIL;
    }
}
