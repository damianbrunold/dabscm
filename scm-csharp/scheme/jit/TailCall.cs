namespace scheme;

// A value that compiled code returns in place of a result: the nearest
// non-tail caller acts on it (Rt.Signal).
public abstract class Signal
{
}

// A tail call returned instead of made, when the stack is deep
// (Jit.TailDepth): the nearest non-tail caller makes it (Rt.Trampoline).
public sealed class TailCall : Signal
{
    public readonly Lambda fn;
    public readonly object[] frame;

    public TailCall(Lambda fn, object[] frame)
    {
        this.fn = fn;
        this.frame = frame;
    }
}

// The invocation of a continuation of activation target, returned up
// through compiled callers instead of thrown (.NET exceptions are slow):
// non-tail callers return it on, an EscapeCode of target takes its value,
// other code throws it as a ContinuationJump.
public sealed class EscapeSignal : Signal
{
    public readonly Continuation continuation;
    public readonly Activation target;
    public readonly Lambda fn;
    public readonly int ip;
    public readonly object env;

    public EscapeSignal(Continuation continuation, Activation target, Lambda fn, int ip, object env)
    {
        this.continuation = continuation;
        this.target = target;
        this.fn = fn;
        this.ip = ip;
        this.env = env;
    }

    public ContinuationJump ToJump() => new(continuation, target, fn, ip, env);
}
