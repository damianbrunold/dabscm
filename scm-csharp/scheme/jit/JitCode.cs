namespace scheme;

// The code of a compiled lambda. frame holds the arguments from index 1;
// index 0 is free for the parent environment (see ARGS). depth is the
// number of calls below this one in the current VM (compiled calls and
// nested interpreter activations), which bounds the native stack: past
// Jit.MaxDepth calls run in the interpreter.
public abstract class JitCode
{
    public abstract object Call(VM vm, Lambda self, object[] frame, int depth);
}
