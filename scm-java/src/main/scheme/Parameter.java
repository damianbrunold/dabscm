package scheme;

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
// pure Scheme and we don't need to call back into the VM from Java.
public final class Parameter extends Primitive {
    private static final Object UNSET = new Object();

    private final Object defaultValue;
    private final ThreadLocal<Object> tls = ThreadLocal.withInitial(() -> UNSET);

    public Parameter(Object defaultValue) {
        this.defaultValue = defaultValue;
    }

    @Override
    public String name() { return "parameter"; }

    @Override
    public String info() {
        return "A parameter object created by make-parameter. Call with no args " +
               "to read the calling thread's current value, or with one arg to " +
               "set it. See SRFI 39 / R7RS make-parameter and parameterize.";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        if (arguments.length == 0) {
            Object v = tls.get();
            return v == UNSET ? defaultValue : v;
        }
        tls.set(arguments[0]);
        return arguments[0];
    }
}
