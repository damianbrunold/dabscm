package scheme.primitives;

import scheme.*;
import java.util.Locale;

public class PrimitiveStringUpcase extends Primitive {
    @Override public String name() { return "string-upcase"; }

    @Override public String info() {
        return "Syntax: (string-upcase s)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns a string that is the uppercase equivalent of s using full Unicode case mapping.";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.toUpper(new String(Value.asString(arguments[0]))).toCharArray();
    }
}
