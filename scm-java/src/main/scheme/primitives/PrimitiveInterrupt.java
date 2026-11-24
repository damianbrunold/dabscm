package scheme.primitives;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicBoolean;
import scheme.*;

/**
 * set-interrupt-handler! and take-interrupt! ((scm system)): what Ctrl+C
 * (SIGINT) does. The handler is installed through reflection on
 * sun.misc.Signal (module jdk.unsupported), as TerminalState does; it is a
 * handler, not SIG_IGN, so child processes still get Ctrl+C. 'default puts
 * back the JVM's own handler (which runs the shutdown hooks and exits).
 */
public class PrimitiveInterrupt extends Primitive {
    private static final String[] MODES = { "default", "ignore", "record" };
    private static volatile int mode = 0;
    private static final AtomicBoolean interrupted = new AtomicBoolean(false);
    private static Object signal;
    private static Object original;
    private static boolean installed = false;

    private final String name;

    public PrimitiveInterrupt(String name) {
        this.name = name;
    }

    @Override
    public String name() { return name; }

    @Override
    public String info() {
        if (name.equals("take-interrupt!"))
            return "Syntax: (take-interrupt!)\n" +
                   "Library: (scm system)\n" +
                   "Description: Returns #t if an interrupt (Ctrl+C) was recorded since the last call\n" +
                   "  (set-interrupt-handler! 'record), else #f.\n" +
                   "Example:\n" +
                   "  (when (take-interrupt!) (display \"^C\"))";
        return "Syntax: (set-interrupt-handler! mode)\n" +
               "Library: (scm system)\n" +
               "Description: Sets what an interrupt (Ctrl+C, SIGINT; Ctrl+Break on Windows) does:\n" +
               "  'default ends the program (as at the start), 'ignore does nothing, 'record\n" +
               "  records it for take-interrupt!. Child processes are not affected: a program\n" +
               "  run in the foreground still gets Ctrl+C. Returns the mode before.\n" +
               "Example:\n" +
               "  (set-interrupt-handler! 'ignore) => default\n" +
               "  (run-program '(\"sleep\" \"10\"))     ; Ctrl+C ends sleep, not the caller\n" +
               "  (set-interrupt-handler! 'default) => ignore";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (name.equals("take-interrupt!")) {
            checkArgs(pos, arguments, 0, 0);
            return interrupted.getAndSet(false);
        }
        checkArgs(pos, arguments, 1, 1);
        int m = -1;
        if (Value.isSymbol(arguments[0])) {
            String s = Value.asSymbol(arguments[0]);
            for (int i = 0; i < MODES.length; i++) if (MODES[i].equals(s)) m = i;
        }
        if (m < 0)
            throw new SchemeError(pos, "set-interrupt-handler!: expected 'default, 'ignore or 'record");
        int before = mode;
        mode = m;
        try {
            install(m != 0);
        } catch (Throwable t) {
            // no sun.misc.Signal: the mode has no effect
        }
        return Value.intern(MODES[before]);
    }

    private static synchronized void install(boolean on) throws Exception {
        if (on == installed) return;
        Class<?> signalClass = Class.forName("sun.misc.Signal");
        Class<?> handlerClass = Class.forName("sun.misc.SignalHandler");
        if (signal == null) signal = signalClass.getConstructor(String.class).newInstance("INT");
        Method handle = signalClass.getMethod("handle", signalClass, handlerClass);
        if (on) {
            InvocationHandler ih = (Object proxy, Method method, Object[] args) -> {
                switch (method.getName()) {
                    case "handle":
                        if (mode == 2) interrupted.set(true);
                        return null;
                    case "hashCode": return System.identityHashCode(proxy);
                    case "equals": return proxy == args[0];
                    case "toString": return "scm-interrupt-handler";
                    default: return null;
                }
            };
            Object handler = Proxy.newProxyInstance(handlerClass.getClassLoader(),
                                                    new Class<?>[] { handlerClass }, ih);
            original = handle.invoke(null, signal, handler);
        } else {
            handle.invoke(null, signal, original);
            original = null;
        }
        installed = on;
    }
}
