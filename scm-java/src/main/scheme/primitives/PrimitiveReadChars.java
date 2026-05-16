package scheme.primitives;

import scheme.*;

public class PrimitiveReadChars extends Primitive {
    private Modules modules;

    public PrimitiveReadChars(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "read-chars";
    }

    @Override
    public String info() {
        return "Syntax: (read-chars n port)\n" +
               "Library: (scm io)\n" +
               "Description: Reads up to n characters from the textual input port and returns them as a string. Returns an end-of-file object if no characters are available.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"hello\"))\n" +
               "  (read-chars 3 p) => \"hel\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        int size = IntegerMath.toInt(arguments[0]);
        TextStream port;
        if (arguments.length == 1) {
            port = Value.asInputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*input-port*"));
        } else {
            port = Value.asInputPort(arguments[1]);
        }
        try {
            int c = port.read();
            if (c == -1) return Value.EOF;
            StringBuilder result = new StringBuilder();
            while (c != -1) {
                char ch = (char) c;
                result.append(ch);
                if (result.length() == size) {
                    break;
                }
                c = port.read();
            }
            return result.toString().toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
