package scheme.primitives;
import scheme.*;

public class PrimitiveThreadStartB extends Primitive {
    @Override
    public String name() { return "thread-start!"; }

    @Override
    public String info() {
        return "Syntax: (thread-start! thread)\n" +
               "Library: (srfi 18)\n" +
               "Description: Makes thread runnable. The thread will execute its thunk in a new\n" +
               "  execution context with its own dynamic environment inherited from the creating\n" +
               "  thread. Returns the thread.\n" +
               "Example:\n" +
               "  (thread-start! (make-thread (lambda () 42)))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;
        if (t.state != SchemeThread.State.NEW)
            throw new SchemeError(pos, "thread-start!: thread already started");
        Lambda lambda = t.lambda;
        t.state = SchemeThread.State.STARTED;
        t.thread = new Thread(() -> {
            SchemeThread.currentThread.set(t);
            try {
                // Share Modules directly with the parent thread. Bindings
                // are now Cell-indirected and currentModule/loadingModules
                // are per-thread, so set! on top-level bindings is visible
                // across threads. See notes/threading-shared-bindings.md.
                VM vm = new VM(t.modules);
                Lambda wrapper = new Lambda(Value.NIL, Instruction.seq(
                    new Instruction(Opcode.ARGS, 0),
                    new Instruction(Opcode.CONST, lambda),
                    new Instruction(Opcode.CALLJ, 0)));
                t.result = vm.execute(wrapper);
            } catch (SchemeError e) {
                t.exception = e.errorObject != null
                    ? (Object) e.errorObject
                    : e.getMessage();
                t.originalError = e;
            } catch (Exception e) {
                t.exception = e.getMessage();
            } finally {
                t.state = SchemeThread.State.TERMINATED;
            }
        });
        t.thread.setDaemon(true);
        t.thread.start();
        return arguments[0];
    }
}
