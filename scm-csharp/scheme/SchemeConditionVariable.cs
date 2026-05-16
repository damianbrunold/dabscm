using System.Threading;

namespace scheme;

public class SchemeConditionVariable
{
    public readonly object Lock = new object();
    public object name = Value.F;
    public object specific = Value.NIL;

    public void Signal()
    {
        lock (Lock) { Monitor.Pulse(Lock); }
    }

    public void Broadcast()
    {
        lock (Lock) { Monitor.PulseAll(Lock); }
    }

    public bool Wait(int timeoutMs)
    {
        lock (Lock) { return Monitor.Wait(Lock, timeoutMs); }
    }

    public void Wait()
    {
        lock (Lock) { Monitor.Wait(Lock); }
    }

    public override string ToString() =>
        !name.Equals(Value.F) ? "#<condition-variable " + Value.DisplayRep(name) + ">" : "#<condition-variable>";
}
