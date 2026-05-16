package scheme.primitives;
import scheme.*;

public class PrimitiveExceptionHandlersGet extends Primitive {
    @Override public String name() { return "%exception-handlers-get"; }
    @Override public String info() {
        return "Syntax: (%exception-handlers-get)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Returns the current VM's exception handler stack as a list.\n" +
               "Example:\n" +
               "  (%exception-handlers-get) => ()";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 0, 0);
        VM vm = VM.current.get();
        return vm != null ? vm.exceptionHandlers : Value.NIL;
    }
}
