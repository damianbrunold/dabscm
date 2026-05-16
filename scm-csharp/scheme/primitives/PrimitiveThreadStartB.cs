using System;
using System.Threading.Tasks;

namespace scheme;

public class PrimitiveThreadStartB : Primitive
{
    public override string Name() => "thread-start!";

    public override string Info() =>
        "Syntax: (thread-start! thread)\n" +
        "Library: (srfi 18)\n" +
        "Description: Makes thread runnable. The thread will execute its thunk in a new\n" +
        "  execution context with its own dynamic environment inherited from the creating\n" +
        "  thread. Returns the thread.\n" +
        "Example:\n" +
        "  (thread-start! (make-thread (lambda () 42)))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;
        if (t.state != SchemeThreadState.NEW)
            throw new SchemeError(pos, "thread-start!: thread already started");
        Lambda lambda = t.lambda!;
        t.state = SchemeThreadState.STARTED;
        t.task = Task.Factory.StartNew(() =>
        {
            SchemeThread.CurrentThread = t;
            try
            {
                VM vm = new VM(t.modules.DeepClone());
                Lambda wrapper = new Lambda(Value.NIL, Instruction.Seq(
                    new Instruction(Opcode.ARGS, 0),
                    new Instruction(Opcode.CONST, lambda),
                    new Instruction(Opcode.CALLJ, 0)));
                t.result = vm.Execute(wrapper);
            }
            catch (SchemeError e)
            {
                t.exception = e.errorObject != null
                    ? (object) e.errorObject
                    : e.Message;
                t.originalError = e;
            }
            catch (Exception e)
            {
                t.exception = e.Message;
            }
            finally
            {
                t.state = SchemeThreadState.TERMINATED;
            }
        });
        return arguments[0];
    }
}
