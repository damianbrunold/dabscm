namespace scheme;

// The invocation of a continuation captured in another activation than
// the current one: unwinds to target, which restores the continuation's
// stack and continues in fn (the continuation procedure) at ip with env.
public sealed class ContinuationJump : Exception
{
    public readonly Continuation continuation;
    public readonly Activation target;
    public readonly Lambda fn;
    public readonly int ip;
    public readonly object env;

    public ContinuationJump(Continuation continuation, Activation target, Lambda fn, int ip, object env)
    {
        this.continuation = continuation;
        this.target = target;
        this.fn = fn;
        this.ip = ip;
        this.env = env;
    }
}
