package scheme.primitives;
import scheme.*;
import scheme.jit.Jit;

public class PrimitiveEscapeOnlyReceiverP extends Primitive {
    @Override public String name() { return "%escape-only-receiver?"; }
    @Override public String info() {
        return "Syntax: (%escape-only-receiver? proc)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if proc is a procedure of one parameter that only calls\n" +
               "  the parameter directly in its own body, so that a continuation passed to it\n" +
               "  can only be invoked within the dynamic extent of the call. call/cc then\n" +
               "  captures an escape continuation, which is cheaper with compiled code.\n" +
               "Example:\n" +
               "  (%escape-only-receiver? (lambda (return) (return 1))) => #t";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        return args[0] instanceof Lambda && Jit.escapeOnly((Lambda) args[0]) ? Value.T : Value.F;
    }
}
