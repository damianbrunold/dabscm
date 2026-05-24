package scheme.primitives;

import scheme.*;

import java.io.Writer;

public class PrimitiveWriteString extends Primitive {
    private Modules modules;

    public PrimitiveWriteString(Modules modules) {
        this.modules = modules;
    }

    @Override public String name() { return "write-string"; }
    @Override public String info() {
        return "Syntax: (write-string string)\n" +
               "       (write-string string port)\n" +
               "       (write-string string port start)\n" +
               "       (write-string string port start end)\n" +
               "Library: (scheme base)\n" +
               "Description: Writes the characters of string from start to " +
               "end in left-to-right order to the given port. port defaults " +
               "to the current output port. start defaults to 0 and end " +
               "defaults to the length of string. The native primitive does " +
               "a single bulk Writer.write(char[], start, count) — large " +
               "strings don't pay the Scheme→native transition per char.\n" +
               "Example:\n" +
               "  (write-string \"hello\")\n" +
               "  (write-string \"hello\" port 1 3)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 4);
        char[] s = Value.asString(arguments[0]);
        Writer port;
        if (arguments.length >= 2) {
            port = Value.asOutputPort(arguments[1]);
        } else {
            port = Value.asOutputPort(
                modules.getModuleRequired(pos, "scm core")
                       .resolve(pos, "*output-port*"));
        }
        int start = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : 0;
        int end   = arguments.length >= 4 ? IntegerMath.toInt(arguments[3]) : s.length;
        try {
            port.write(s, start, end - start);
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "write-string: io failure: ~s", e.getMessage());
        }
    }
}
