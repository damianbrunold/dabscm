using System.Threading;
using System.Threading.Tasks;

namespace scheme;

public enum SchemeThreadState { NEW, STARTED, TERMINATED }

public class SchemeThread
{
    [ThreadStatic]
    public static SchemeThread? CurrentThread;

    // the one Scheme value of this thread, so that current-thread,
    // make-thread and mutex-state give eq? objects (SRFI 18)
    private NativeValue? value;

    public NativeValue AsValue()
    {
        lock (this)
        {
            value ??= new NativeValue(this);
            return value;
        }
    }

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
