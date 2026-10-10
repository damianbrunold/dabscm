package scheme.primitives;

import scheme.*;

public class PrimitivePortPosition extends Primitive {
    private Modules modules;

    public PrimitivePortPosition(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "port-position";
    }

    @Override
    public String info() {
        return "Syntax: (port-position port)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the current position of the textual input port as a list (filename line column): line 1-based, column 0-based, filename \"{string}\" for string ports.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"hello\"))\n" +
               "  (port-position p) => (\"{string}\" 1 0)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        TextStream port;
        if (arguments.length == 0) {
            port = Value.asInputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*input-port*"));
        }
        else {
            port = Value.asInputPort(arguments[0]);
        }
	// line/column as Scheme integers (Long); string ports have no file
	// name and report "{string}"
	String filename = port.filename();
	return new Pair(
	    (filename != null ? filename : "{string}").toCharArray(),
	    new Pair(
		(long) port.line(),
		new Pair(
		    (long) port.column(),
		    Value.NIL)));
    }
}
