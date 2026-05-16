using System;

namespace scheme;

public class PrimitiveThreadJoinB : Primitive
{
    public override string Name() => "thread-join!";

    public override string Info() =>
        "Syntax: (thread-join! thread [timeout [timeout-val]])\n" +
        "Library: (srfi 18)\n" +
        "Description: Waits for thread to terminate. Returns the thread's result value.\n" +
        "  If timeout is given and reached, returns timeout-val or raises a\n" +
        "  join-timeout-exception. If the thread terminated with an uncaught exception,\n" +
        "  raises an uncaught-exception.\n" +
        "Example:\n" +
        "  (thread-join! (thread-start! (make-thread (lambda () 42)))) => 42";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        SchemeThread t = (SchemeThread) Value.AsNativeValue(arguments[0]).value;

        bool hasTimeout = arguments.Length >= 2 && !arguments[1].Equals(Value.F);
        int timeoutMs = -1; // -1 means infinite

        if (hasTimeout)
        {
            double seconds;
            if (Value.IsReal(arguments[1]))
                seconds = Value.AsReal(arguments[1]);
            else if (Value.IsInteger(arguments[1]))
                seconds = IntegerMath.ToDouble(arguments[1]);
            else
                throw new SchemeError(pos, "thread-join!: invalid timeout ~s", arguments[1]);
            timeoutMs = seconds <= 0 ? 0 : (int)(seconds * 1000);
        }

        bool completed;
        if (t.task != null)
        {
            if (timeoutMs < 0)
            {
                t.task.Wait();
                completed = true;
            }
            else
            {
                completed = t.task.Wait(timeoutMs);
            }
        }
        else
        {
            completed = t.state == SchemeThreadState.TERMINATED;
        }

        if (!completed)
        {
            if (arguments.Length >= 3)
                return arguments[2];
            throw new SchemeError(pos, new ErrorObject("join-timeout-exception",
                new object[] { new NativeValue(new SchemeThreadException(ThreadExceptionKind.JOIN_TIMEOUT)) }));
        }

        if (t.exception != null)
        {
            var wrapper = new SchemeError(pos, new ErrorObject("uncaught-exception",
                new object[] { new NativeValue(new SchemeThreadException(ThreadExceptionKind.UNCAUGHT, t.exception)) }));
            wrapper.parent = t.originalError;
            throw wrapper;
        }

        if (t.terminated)
        {
            throw new SchemeError(pos, new ErrorObject("terminated-thread-exception",
                new object[] { new NativeValue(new SchemeThreadException(ThreadExceptionKind.TERMINATED_THREAD)) }));
        }

        return t.result;
    }
}
