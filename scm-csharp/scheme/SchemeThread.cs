using System.Threading;
using System.Threading.Tasks;

namespace scheme;

public enum SchemeThreadState { NEW, STARTED, TERMINATED }

public class SchemeThread
{
    [ThreadStatic]
    public static SchemeThread? CurrentThread;

    public Task? task;
    public object result = Value.NIL;
    public Lambda? lambda;
    public Modules modules;
    public object name = Value.F;
    public object specific = Value.NIL;
    public object? exception;
    public SchemeError? originalError;
    public volatile bool terminated;
    public SchemeThreadState state = SchemeThreadState.NEW;

    public SchemeThread(Lambda? lambda, Modules modules)
    {
        this.lambda = lambda;
        this.modules = modules;
    }

    public override string ToString() =>
        !name.Equals(Value.F) ? "#<thread " + Value.DisplayRep(name) + ">" : "#<thread>";
}
