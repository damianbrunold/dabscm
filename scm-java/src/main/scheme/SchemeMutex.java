package scheme;

import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.locks.Condition;

public class SchemeMutex {
    public final ReentrantLock lock = new ReentrantLock(true);
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
