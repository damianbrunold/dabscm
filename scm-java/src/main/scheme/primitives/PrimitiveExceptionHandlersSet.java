package scheme.primitives;
import scheme.*;

public class PrimitiveExceptionHandlersSet extends Primitive {
    @Override public String name() { return "%exception-handlers-set!"; }
    @Override public String info() {
        return "Syntax: (%exception-handlers-set! handlers)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Sets the current VM's exception handler stack to handlers.\n" +
               "Example:\n" +
               "  (%exception-handlers-set! '())";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        VM vm = VM.current.get();
        if (vm != null) vm.exceptionHandlers = args[0];
        return Value.NIL;
    }
}
