package scheme;

public class SchemeThread {
    public static final ThreadLocal<SchemeThread> currentThread = new ThreadLocal<>();

    public enum State { NEW, STARTED, TERMINATED }

    public Thread thread;
    public Object result = Value.NIL;
    public Lambda lambda;
    public Modules modules;
    public Object name = Value.F;
    public Object specific = Value.NIL;
    public Object exception;
    public SchemeError originalError;
    public volatile boolean terminated;
    public State state = State.NEW;

    public SchemeThread(Lambda lambda, Modules modules) {
        this.lambda = lambda;
        this.modules = modules;
    }

    @Override
    public String toString() {
        return name != Value.F ? "#<thread " + Value.displayRep(name) + ">" : "#<thread>";
    }
}
