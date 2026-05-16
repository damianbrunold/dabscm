package scheme.primitives;

import scheme.*;

public class PrimitiveString extends Primitive {
    @Override
    public String name() {
        return "string";
    }

    @Override
    public String info() {
        return "Syntax: (string char ...)\n" +
               "Library: (scheme base) (srfi 13)\n" +
               "Description: Returns a newly allocated string composed of the given characters.\n" +
               "Example:\n" +
               "  (string #\\a #\\b #\\c) => \"abc\"\n" +
               "  (string) => \"\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        StringBuilder result = new StringBuilder();
        for (Object argument : arguments) {
            result.append(Value.asChar(argument));
        }
        return result.toString().toCharArray();
    }
}
