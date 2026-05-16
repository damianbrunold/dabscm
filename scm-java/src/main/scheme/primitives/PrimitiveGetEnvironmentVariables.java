package scheme.primitives;

import java.util.Map;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveGetEnvironmentVariables extends Primitive {
    @Override
    public String name() {
        return "get-environment-variables";
    }

    @Override
    public String info() {
        return "Syntax: (get-environment-variables)\n" +
               "Library: (scheme process-context)\n" +
               "Description: Returns an association list of all environment variables as (name . value) pairs, where both are strings.\n" +
               "Example:\n" +
               "  (assoc \"HOME\" (get-environment-variables)) => (\"HOME\" . \"/home/user\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        Map<String, String> env = System.getenv();
        Object result = Value.NIL;
        for (Map.Entry<String, String> entry : env.entrySet()) {
            char[] key = entry.getKey().toCharArray();
            char[] val = entry.getValue().toCharArray();
            result = new Pair(new Pair(key, val), result);
        }
        return result;
    }
}
