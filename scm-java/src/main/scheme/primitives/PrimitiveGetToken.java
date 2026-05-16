
package scheme.primitives;

import scheme.*;

public class PrimitiveGetToken extends Primitive {
    private Modules modules;

    public PrimitiveGetToken(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "get-token";
    }

    @Override
    public String info() {
        return "Syntax: (get-token) (get-token port)\n" +
               "Library: (scm core)\n" +
               "Description: Reads and returns the next token from the given input port (or current input port). Returns #f at end-of-input.\n" +
               "Example:\n" +
               "  (get-token (open-input-string \"(+ 1 2)\"))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        TextStream port;
        if (arguments.length == 0) {
            port = Value.asInputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*input-port*"));
        } else {
            port = Value.asInputPort(arguments[0]);
        }
        try {
            var token = Tokenizer.readToken(port);
            if (token == null) return Value.F;
		    return token.toSexpr();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
