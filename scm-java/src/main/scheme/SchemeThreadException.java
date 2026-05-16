package scheme;

public class SchemeThreadException {
    public enum Kind { JOIN_TIMEOUT, ABANDONED_MUTEX, TERMINATED_THREAD, UNCAUGHT }

    public Kind kind;
    public Object reason;

    public SchemeThreadException(Kind kind, Object reason) {
        this.kind = kind;
        this.reason = reason;
    }

    public SchemeThreadException(Kind kind) {
        this(kind, null);
    }

    @Override
    public String toString() {
        switch (kind) {
            case JOIN_TIMEOUT: return "#<join-timeout-exception>";
            case ABANDONED_MUTEX: return "#<abandoned-mutex-exception>";
            case TERMINATED_THREAD: return "#<terminated-thread-exception>";
            case UNCAUGHT: return "#<uncaught-exception>";
            default: return "#<thread-exception>";
        }
    }
}
