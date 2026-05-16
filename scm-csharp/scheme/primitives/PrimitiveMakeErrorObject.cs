namespace scheme;

class PrimitiveMakeErrorObject : Primitive {
    public override string Name() => "%make-error-object";
    public override string Info() =>
        "Syntax: (%make-error-object message irritants)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Creates an error object with the given message string and list of irritant objects.\n" +
        "Example:\n" +
        "  (%make-error-object \"bad value\" '(42))";
    public override object Apply(SourcePos? pos, object[] args) {
        CheckArgs(pos, args, 2, 2);
        string message = new string(Value.AsString(args[0]));
        // args[1] is a Scheme list of irritants
        var irritants = new System.Collections.Generic.List<object>();
        object lst = args[1];
        while (lst != Value.NIL) {
            var pair = Value.AsPair(lst);
            irritants.Add(pair.car);
            lst = pair.cdr;
        }
        return new ErrorObject(message, irritants.ToArray());
    }
}
