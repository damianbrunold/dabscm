package scheme.jit;

import java.util.ArrayList;

import scheme.Lambda;

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
public final class FrameCapture extends RuntimeException {
    public static final Object CAPTURE = new Object();

    public final Object cause;
    // the innermost frame's registers
    public final Lambda fn;
    public final int ip;
    public final Object env;
    public final int nargs;
    public final ArrayList<Object[]> segments = new ArrayList<>();
    public final ArrayList<Activation> owners = new ArrayList<>();
    // the activation whose segment was added last (so that it is not added twice)
    public Activation last;

    public FrameCapture(Object cause, Lambda fn, int ip, Object env, int nargs) {
        super(null, null, false, false);
        this.cause = cause;
        this.fn = fn;
        this.ip = ip;
        this.env = env;
        this.nargs = nargs;
    }

    public void add(Object[] segment, Activation owner) {
        segments.add(segment);
        owners.add(owner);
        if (owner != null) last = owner;
    }
}
