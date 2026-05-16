namespace scheme;

class PrimitiveExceptionHandlersGet : Primitive {
    public override string Name() => "%exception-handlers-get";
    public override string Info() =>
        "Syntax: (%exception-handlers-get)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Returns the current VM's exception handler stack as a list.\n" +
        "Example:\n" +
        "  (%exception-handlers-get) => ()";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 0, 0);
        return VM.Current?.exceptionHandlers ?? Value.NIL;
    }
}
