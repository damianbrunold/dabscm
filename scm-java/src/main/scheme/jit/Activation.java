package scheme.jit;

import java.util.ArrayList;

// A run of the interpreter loop on a VM: the root one of VM.execute, or a
// nested one in which compiled code calls an interpreted lambda. Its
// frames are on the VM stack above base (base holds the sentinel return
// address of a nested activation). Escape continuations captured in a
// nested activation hold a copy of its segment and are valid while it is
// alive.
public final class Activation {
    public final Activation parent;
    public final int base;
    public final int depth;
    public final boolean root;
    public boolean alive = true;
    // escape continuations captured in this activation (VM.Continuation)
    public ArrayList<Object> escapes;

    public Activation(Activation parent, int base, int depth, boolean root) {
        this.parent = parent;
        this.base = base;
        this.depth = depth;
        this.root = root;
    }

    public Activation nearestRoot() {
        Activation a = this;
        while (!a.root) a = a.parent;
        return a;
    }
}
