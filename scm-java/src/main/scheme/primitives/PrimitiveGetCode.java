
package scheme.primitives;

import scheme.*;

import java.util.List;
import java.util.ArrayList;

public class PrimitiveGetCode extends Primitive {
    @Override
    public String name() {
        return "get-code";
    }

    @Override
    public String info() {
        return "Syntax: (get-code fn)\n" +
               "Library: (scm compile)\n" +
               "Description: Returns the bytecode instructions of the lambda fn as a list of strings.\n" +
               "Example:\n" +
               "  (get-code (lambda (x) x)) => (\"LOAD_ARG 0\" ...)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        List<Object> result = new ArrayList<>();
        for (var instruction : Value.asLambda(arguments[0]).code) {
            result.add(instruction.toString().toCharArray());
        }
        return Pair.list(result.toArray());
    }
}
