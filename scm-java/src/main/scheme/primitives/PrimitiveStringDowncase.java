package scheme.primitives;

import scheme.*;
import java.util.Locale;

public class PrimitiveStringDowncase extends Primitive {
    @Override public String name() { return "string-downcase"; }

    @Override public String info() {
        return "Syntax: (string-downcase s)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns a string that is the lowercase equivalent of s using full Unicode case mapping.";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.toLower(new String(Value.asString(arguments[0]))).toCharArray();
    }
}
