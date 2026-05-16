using System.Threading;

namespace scheme;

public class SchemeMutex
{
    public readonly object Lock = new object();
    public object name = Value.F;
    public object specific = Value.NIL;
    public SchemeThread? owner;
    public bool abandoned;
    public bool locked;

    public override string ToString() =>
        !name.Equals(Value.F) ? "#<mutex " + Value.DisplayRep(name) + ">" : "#<mutex>";
}
