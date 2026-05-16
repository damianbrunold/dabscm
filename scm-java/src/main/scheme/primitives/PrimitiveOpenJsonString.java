
package scheme.primitives;

import java.io.StringReader;

import scheme.NativeValue;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;
import scheme.json.JsonParser;

public class PrimitiveOpenJsonString extends Primitive {
    @Override
    public String name() {
        return "open-json-string";
    }

    @Override
    public String info() {
        return "Syntax: (open-json-string s)\n" +
               "Library: (scm json)\n" +
               "Description: Returns a JSON reader object that parses the JSON contained in the string s. An optional list-id symbol or string may be specified to identify list nodes.\n" +
               "Example:\n" +
               "  (define r (open-json-string \"{\\\"a\\\": 1}\"))\n" +
               "  (json-next-object r) => parsed object";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String text = new String(Value.asString(arguments[0]));
        var parser = new JsonParser(new StringReader(text));
        if (arguments.length == 2) {
            if (Value.isSymbol(arguments[1])) {
                parser.withListId(Value.asSymbol(arguments[1]));
            } else {
                parser.withListId(new String(Value.asString(arguments[1])));
            }
        }
        return new NativeValue(parser);
    }
}
