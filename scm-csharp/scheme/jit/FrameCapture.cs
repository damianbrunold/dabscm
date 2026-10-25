namespace scheme;

// Unwinds compiled frames and nested activations to the root activation,
// which rebuilds them as interpreter frames on its stack and then handles
// cause: CAPTURE (a full call/cc in a nested activation, re-executed by
// the root), or an error with no exception handler installed (so that the
// error's call stack has every frame).
//
// segments are VM stack contents, innermost first: the innermost frame's
// operand stack, then per compiled frame its operand stack below the call
// and its return address, per nested activation its stack segment. owners
// holds the activation of each segment, null for compiled frames.
public sealed class FrameCapture : Exception
{
    public static readonly object CAPTURE = new();

    public readonly object cause;
    // the innermost frame's registers
    public readonly Lambda fn;
    public readonly int ip;
    public readonly object env;
    public readonly int nargs;
    public readonly List<object[]> segments = new();
    public readonly List<Activation?> owners = new();
    // the activation whose segment was added last (so that it is not added twice)
    public Activation? last;

    public FrameCapture(object cause, Lambda fn, int ip, object env, int nargs)
    {
        this.cause = cause;
        this.fn = fn;
        this.ip = ip;
        this.env = env;
        this.nargs = nargs;
    }

    public void Add(object[] segment, Activation? owner)
    {
        segments.Add(segment);
        owners.Add(owner);
        if (owner != null) last = owner;
    }
}
