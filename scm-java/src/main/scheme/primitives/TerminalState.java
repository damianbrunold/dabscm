package scheme.primitives;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Shared terminal state: SIGWINCH tracking and a cached terminal size.
 * The signal handler is installed through reflection on sun.misc.Signal
 * (module jdk.unsupported), so the code still compiles and runs where it
 * is missing; resize tracking is then simply unavailable.
 */
final class TerminalState {
    private TerminalState() {}

    private static final AtomicLong resizeCount = new AtomicLong(0);
    private static volatile boolean installed = false;
    private static volatile boolean installAttempted = false;
    static volatile Object cachedSize = null;

    static synchronized boolean installResizeHandler() {
        if (installAttempted) return installed;
        installAttempted = true;
        if (System.getProperty("os.name").toLowerCase().contains("windows")) return false;
        try {
            Class<?> signalClass = Class.forName("sun.misc.Signal");
            Class<?> handlerClass = Class.forName("sun.misc.SignalHandler");
            Object signal = signalClass.getConstructor(String.class).newInstance("WINCH");
            InvocationHandler ih = (Object proxy, Method method, Object[] args) -> {
                if (method.getName().equals("handle")) {
                    cachedSize = null;
                    resizeCount.incrementAndGet();
                    return null;
                }
                if (method.getName().equals("hashCode")) return System.identityHashCode(proxy);
                if (method.getName().equals("equals")) return proxy == args[0];
                if (method.getName().equals("toString")) return "scm-winch-handler";
                return null;
            };
            Object handler = Proxy.newProxyInstance(handlerClass.getClassLoader(),
                                                    new Class<?>[] { handlerClass }, ih);
            signalClass.getMethod("handle", signalClass, handlerClass).invoke(null, signal, handler);
            installed = true;
        } catch (Throwable t) {
            installed = false;
        }
        return installed;
    }

    static boolean resizeTracked() {
        return installed;
    }

    static long resizeCount() {
        return resizeCount.get();
    }
}
