package scheme.jit;

import scheme.Lambda;
import scheme.VM;

// The JVM code of a compiled lambda. frame holds the arguments from
// index 1; index 0 is free for the parent environment (see ARGS). depth
// is the number of Java-level calls below this one in the current VM
// (compiled calls and nested interpreter activations), which bounds the
// Java stack: past Jit.maxDepth calls run in the interpreter.
public abstract class JitCode {
    public abstract Object call(VM vm, Lambda self, Object[] frame, int depth);
}
