package scheme.jit;

import scheme.Lambda;

// A tail call returned instead of made, when the Java stack is deep
// (Jit.tailDepth): the nearest non-tail caller makes it (Rt.trampoline).
public final class TailCall {
    public final Lambda fn;
    public final Object[] frame;

    public TailCall(Lambda fn, Object[] frame) {
        this.fn = fn;
        this.frame = frame;
    }
}
