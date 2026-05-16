package scheme.primitives;

import scheme.Primitive;
import scheme.UnicodeCaseMap;
import scheme.Value;
import scheme.SourcePos;

public class PrimitiveStringFoldcase extends Primitive {
    @Override
    public String name() {
        return "string-foldcase";
    }

    @Override
    public String info() {
        return "Syntax: (string-foldcase s)\n" +
               "Library: (scheme char)\n" +
               "Description: Returns a string that is the result of applying Unicode case folding to s, which lowercases the string in a locale-independent manner.\n" +
               "Example:\n" +
               "  (string-foldcase \"Hello\") => \"hello\"\n" +
               "  (string-foldcase \"SCHEME\") => \"scheme\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.toFold(new String(Value.asString(arguments[0]))).toCharArray();
    }
}
