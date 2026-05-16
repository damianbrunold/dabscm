package scheme.primitives;

import scheme.*;

public class PrimitiveValues extends Primitive {
    @Override
    public String name() {
        return "values";
    }

    @Override
    public String info() {
        return "Syntax: (values obj ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns all of its arguments as multiple values. Used with call-with-values to pass multiple results between procedures.\n" +
               "Example:\n" +
               "  (values 1 2 3) => 1 2 3\n" +
               "  (call-with-values (lambda () (values 4 5)) +) => 9";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 1) return arguments[0];
        Values result = new Values();
        result.values = arguments; // TODO maybe need to copy?
        return result;
    }
}
