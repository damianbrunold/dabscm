using System;
using System.Threading;

namespace scheme;

public class PrimitiveMutexUnlockB : Primitive
{
    public override string Name() => "mutex-unlock!";

    public override string Info() =>
        "Syntax: (mutex-unlock! mutex [condition-variable [timeout]])\n" +
        "Library: (srfi 18)\n" +
        "Description: Unlocks the mutex. If a condition-variable is given, the current\n" +
        "  thread is blocked and added to the condition-variable's wait queue, and the\n" +
        "  mutex is atomically unlocked. Returns #t if the thread was signaled, #f if\n" +
        "  timed out.\n" +
        "Example:\n" +
        "  (mutex-unlock! m)\n" +
        "  (mutex-unlock! m cv 1.0)  ; unlock and wait on cv up to 1s";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;

        lock (m.Lock)
        {
            m.locked = false;
            m.owner = null;
            Monitor.PulseAll(m.Lock);
        }

        if (arguments.Length >= 2)
        {
            SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[1]).value;

            bool hasTimeout = arguments.Length >= 3 && !arguments[2].Equals(Value.F);
            int timeoutMs = -1;

            if (hasTimeout)
            {
                double seconds;
                if (Value.IsReal(arguments[2]))
                    seconds = Value.AsReal(arguments[2]);
                else if (Value.IsInteger(arguments[2]))
                    seconds = IntegerMath.ToDouble(arguments[2]);
                else
                    throw new SchemeError(pos, "mutex-unlock!: invalid timeout ~s", arguments[2]);
                timeoutMs = seconds <= 0 ? 0 : (int)(seconds * 1000);
            }

            if (timeoutMs < 0)
            {
                cv.Wait();
                return Value.T;
            }
            else
            {
                return cv.Wait(timeoutMs) ? Value.T : Value.F;
            }
        }

        return Value.T;
    }
}
