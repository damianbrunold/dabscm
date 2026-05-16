using System;
using System.Threading;

namespace scheme;

public class PrimitiveMutexLockB : Primitive
{
    public override string Name() => "mutex-lock!";

    public override string Info() =>
        "Syntax: (mutex-lock! mutex [timeout [thread]])\n" +
        "Library: (srfi 18)\n" +
        "Description: Locks the mutex. If already locked, blocks until available or timeout.\n" +
        "  Returns #t if locked successfully, #f if timed out. If the mutex was abandoned\n" +
        "  by a terminated thread, locks it but raises an abandoned-mutex-exception.\n" +
        "Example:\n" +
        "  (mutex-lock! m) => #t\n" +
        "  (mutex-lock! m 0.5) => #f  ; if not acquired within 0.5s";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;

        bool hasTimeout = arguments.Length >= 2 && !arguments[1].Equals(Value.F);
        int timeoutMs = -1;

        if (hasTimeout)
        {
            double seconds;
            if (Value.IsReal(arguments[1]))
                seconds = Value.AsReal(arguments[1]);
            else if (Value.IsInteger(arguments[1]))
                seconds = IntegerMath.ToDouble(arguments[1]);
            else
                throw new SchemeError(pos, "mutex-lock!: invalid timeout ~s", arguments[1]);
            timeoutMs = seconds <= 0 ? 0 : (int)(seconds * 1000);
        }

        bool acquired;
        lock (m.Lock)
        {
            if (!m.locked)
            {
                m.locked = true;
                m.owner = SchemeThread.CurrentThread;
                bool wasAbandoned = m.abandoned;
                m.abandoned = false;
                if (wasAbandoned)
                    throw new SchemeError(pos, new ErrorObject("abandoned-mutex-exception",
                        new object[] { new NativeValue(new SchemeThreadException(ThreadExceptionKind.ABANDONED_MUTEX)) }));
                return Value.T;
            }

            if (timeoutMs == 0)
                return Value.F;

            if (timeoutMs < 0)
            {
                while (m.locked)
                    Monitor.Wait(m.Lock);
            }
            else
            {
                long deadline = Environment.TickCount64 + timeoutMs;
                while (m.locked)
                {
                    long remaining = deadline - Environment.TickCount64;
                    if (remaining <= 0) return Value.F;
                    Monitor.Wait(m.Lock, (int) remaining);
                }
            }

            m.locked = true;
            m.owner = SchemeThread.CurrentThread;
            acquired = true;
            bool wasAbandoned2 = m.abandoned;
            m.abandoned = false;
            if (wasAbandoned2)
                throw new SchemeError(pos, new ErrorObject("abandoned-mutex-exception",
                    new object[] { new NativeValue(new SchemeThreadException(ThreadExceptionKind.ABANDONED_MUTEX)) }));
        }
        return acquired ? Value.T : Value.F;
    }
}
