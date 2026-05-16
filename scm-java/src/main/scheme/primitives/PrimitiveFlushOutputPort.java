package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveFlushOutputPort extends Primitive {
    private Modules modules;

    public PrimitiveFlushOutputPort(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "flush-output-port";
    }

    @Override
    public String info() {
        return "Syntax: (flush-output-port) (flush-output-port port)\n" +
               "Library: (scheme base)\n" +
               "Description: Flushes any buffered output in the given output port (or current output port if omitted).\n" +
               "Example:\n" +
               "  (flush-output-port)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        Object portObj;
        if (arguments.length == 0) {
            portObj = modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*");
        } else {
            portObj = arguments[0];
        }
        try {
            if (Value.isBinaryOutputPort(portObj)) {
                // Binary output ports have no flush; treat as no-op
                return new Values();
            }
            Writer port = Value.asOutputPort(portObj);
            port.flush();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure");
        }
    }
}
