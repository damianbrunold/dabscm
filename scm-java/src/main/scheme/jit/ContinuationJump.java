package scheme.jit;

import scheme.Lambda;

// The invocation of a continuation captured in another activation than
// the current one: unwinds to target, which restores the continuation's
// stack and continues in fn (the continuation procedure) at ip with env.
public final class ContinuationJump extends RuntimeException {
    public final Object continuation;
    public final Activation target;
    public final Lambda fn;
    public final int ip;
    public final Object env;

    public ContinuationJump(Object continuation, Activation target, Lambda fn, int ip, Object env) {
        super(null, null, false, false);
        this.continuation = continuation;
        this.target = target;
        this.fn = fn;
        this.ip = ip;
        this.env = env;
    }
}
