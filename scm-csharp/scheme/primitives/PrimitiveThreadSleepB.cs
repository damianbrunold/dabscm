using System;
using System.Threading;

namespace scheme;

public class PrimitiveThreadSleepB : Primitive
{
    public override string Name() => "thread-sleep!";

    public override string Info() =>
        "Syntax: (thread-sleep! timeout)\n" +
        "Library: (srfi 18)\n" +
        "Description: Causes the current thread to sleep. The timeout can be a time " +
        "object (absolute time) or a number (relative seconds).\n" +
        "Example:\n" +
        "  (thread-sleep! 0.1)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        int ms;
        if (Value.IsInteger(arguments[0]))
        {
            ms = (int)(IntegerMath.ToLong(arguments[0]) * 1000);
        }
        else if (Value.IsReal(arguments[0]))
        {
            ms = (int)(Value.AsReal(arguments[0]) * 1000);
        }
        else
        {
            throw new SchemeError(pos, "thread-sleep!: expected time object or number, got ~s", arguments[0]);
        }
        if (ms > 0)
            Thread.Sleep(ms);
        return Value.NIL;
    }
}
