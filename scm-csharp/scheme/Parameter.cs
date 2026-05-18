namespace scheme;

// A SRFI 39 / R7RS parameter object backed by a host thread-local.
//
// `(param)` returns the calling thread's current value, falling back to
// the default (the initial value passed to make-parameter) if this thread
// has never set the parameter. `(param val)` sets the calling thread's
// value. Because storage is per-thread, parameterize's prologue/epilogue
// can't race across threads — see notes/threading-shared-bindings.md.
//
// The Scheme-side `make-parameter` wraps this in a closure that applies
// the optional converter procedure, so the converter logic stays in
// pure Scheme and we don't need to call back into the VM from C#.
public sealed class Parameter : Primitive
{
    private readonly object defaultValue;
    private readonly ThreadLocal<object> tls = new();

    public Parameter(object defaultValue)
    {
        this.defaultValue = defaultValue;
    }

    public override string Name() => "parameter";

    public override string Info() =>
        "A parameter object created by make-parameter. Call with no args " +
        "to read the calling thread's current value, or with one arg to " +
        "set it. See SRFI 39 / R7RS make-parameter and parameterize.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        if (arguments.Length == 0)
        {
            return tls.IsValueCreated ? tls.Value! : defaultValue;
        }
        tls.Value = arguments[0];
        return arguments[0];
    }
}
