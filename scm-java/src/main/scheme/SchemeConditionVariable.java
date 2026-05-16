package scheme;

import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.TimeUnit;

public class SchemeConditionVariable {
    public final ReentrantLock lock = new ReentrantLock();
    public final Condition condition = lock.newCondition();
    public Object name = Value.F;
    public Object specific = Value.NIL;

    public void signal() {
        lock.lock();
        try { condition.signal(); }
        finally { lock.unlock(); }
    }

    public void broadcast() {
        lock.lock();
        try { condition.signalAll(); }
        finally { lock.unlock(); }
    }

    public boolean await(long timeoutMs) throws InterruptedException {
        lock.lock();
        try { return condition.await(timeoutMs, TimeUnit.MILLISECONDS); }
        finally { lock.unlock(); }
    }

    public void awaitUninterruptibly() {
        lock.lock();
        try { condition.await(); }
        catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        finally { lock.unlock(); }
    }

    @Override
    public String toString() {
        return name != Value.F ? "#<condition-variable " + Value.displayRep(name) + ">" : "#<condition-variable>";
    }
}
