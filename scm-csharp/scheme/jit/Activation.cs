namespace scheme;

// A run of the interpreter loop on a VM: the root one of VM.Execute, or a
// nested one in which compiled code calls an interpreted lambda (or a
// JitBuiltins escape). Its frames are on the VM stack above Base (Base
// holds the sentinel return address of a nested activation). Escape
// continuations captured in a nested activation hold a copy of its
// segment and are valid while it is alive.
public sealed class Activation
{
    public readonly Activation? parent;
    public readonly int Base;
    public readonly int depth;
    public readonly bool root;
    public bool alive = true;
    // escape continuations captured in this activation (weak references)
    public List<WeakReference<Continuation>>? escapes;

    public Activation(Activation? parent, int Base, int depth, bool root)
    {
        this.parent = parent;
        this.Base = Base;
        this.depth = depth;
        this.root = root;
    }

    public Activation NearestRoot()
    {
        Activation a = this;
        while (!a.root) a = a.parent!;
        return a;
    }
}
