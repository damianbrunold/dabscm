package scheme;

import java.util.Arrays;

import scheme.jit.Activation;

// The value stack of a continuation, restored by SETCC. Sharing the
// ReturnAddress entries is safe: they are never modified. A full
// continuation (act null) holds the whole stack. An escape continuation
// holds the stack segment of the activation act it was captured in and can
// be invoked while act is alive (scheme.jit.Activation).
final class Continuation {
    Object[] stack;
    Activation act;

    Continuation(Object[] stack, int sp) {
        this.stack = Arrays.copyOf(stack, sp);
    }

    Continuation(Object[] stack, int from, int to, Activation act) {
        this.stack = Arrays.copyOfRange(stack, from, to);
        this.act = act;
    }
}
