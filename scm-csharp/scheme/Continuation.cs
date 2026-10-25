namespace scheme;

// The value stack of a continuation, restored by SETCC. Sharing the
// ReturnAddress entries is safe: they are never modified. A full
// continuation (act null) holds the whole stack. An escape continuation
// holds the stack segment of the activation act it was captured in and can
// be invoked while act is alive (Activation).
public sealed class Continuation
{
    public object[] stack;
    public Activation? act;

    public Continuation(object[] stack, int sp)
    {
        this.stack = stack[..sp];
    }

    public Continuation(object[] stack, int from, int to, Activation act)
    {
        this.stack = stack[from..to];
        this.act = act;
    }
}
