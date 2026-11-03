package scheme;

import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.locks.Condition;

public class SchemeMutex {
    // Guards the fields below for a few instructions at a time. Not fair:
    // a fair lock hands over in strict order and costs a context switch per
    // hand-over under contention, and SRFI-18 promises no ordering.
    public final ReentrantLock lock = new ReentrantLock();
    public final Condition condition = lock.newCondition();
    public Object name = Value.F;
    public Object specific = Value.NIL;
    public SchemeThread owner;
    public boolean abandoned;
    public boolean locked;

    @Override
    public String toString() {
        return name != Value.F ? "#<mutex " + Value.displayRep(name) + ">" : "#<mutex>";
    }
}
