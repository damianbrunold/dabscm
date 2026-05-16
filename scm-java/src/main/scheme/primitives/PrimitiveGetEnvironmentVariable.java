package scheme.primitives;

import scheme.*;

public class PrimitiveGetEnvironmentVariable extends Primitive {
    @Override
    public String name() {
        return "get-environment-variable";
    }

    @Override
    public String info() {
        return "Syntax: (get-environment-variable name)\n" +
               "Library: (scm system) (scheme process-context) (srfi 98)\n" +
               "Description: Returns the value of the environment variable named name as a string, or #f if it is not set.\n" +
               "Example:\n" +
               "  (get-environment-variable \"HOME\") => \"/home/user\"\n" +
               "  (get-environment-variable \"UNDEFINED_VAR\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var name = new String(Value.asString(arguments[0]));
        var value = System.getenv(name);
        if (value != null) {
            return value.toCharArray();
        } else {
            return Value.F;
        }
    }
}
