package scheme.primitives;

import scheme.*;

public class PrimitiveExit extends Primitive {
    private final Modules modules;

    public PrimitiveExit(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "exit";
    }

    @Override
    public String info() {
        return "Syntax: (exit) (exit obj)\n" +
               "Library: (scheme process-context)\n" +
               "Description: Terminates the current program. If obj is an exact integer, it is used as the exit code. Without an argument, exits with code 1.\n" +
               "Example:\n" +
               "  (exit)\n" +
               "  (exit 0)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        // System.exit terminates the JVM without flushing the buffered
        // stdout/stderr writers, so anything displayed just before (exit)
        // would be lost. Flush the output ports first. (.NET's Console.Out
        // auto-flushes, so the C# side needs no equivalent.)
        flushOutputPorts();
        // TODO switch to throw new SchemeExit
        if (arguments.length == 0) {
            System.exit(1);
        } else {
            System.exit(IntegerMath.toInt(arguments[0]));
        }
        return new Values();
    }

    private void flushOutputPorts() {
        try {
            scheme.Module core = modules.getModuleRequired(null, "scm core");
            for (String portName : new String[] { "*output-port*", "*error-port*" }) {
                Object port = core.resolve(portName);
                if (Value.isOutputPort(port)) {
                    Value.asOutputPort(port).flush();
                }
            }
        } catch (Exception ignored) {
        }
    }
}
