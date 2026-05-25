
package scheme.primitives;

import java.io.*;
import java.nio.charset.Charset;

import scheme.Encoding;
import scheme.NativeValue;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.json.JsonParser;

public class PrimitiveOpenJsonFile extends Primitive {
    @Override
    public String name() {
        return "open-json-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-json-file filename)\n" +
               "Library: (scm core)\n" +
               "Description: Opens the named JSON file and returns a JSON reader object. An optional list-id symbol may be specified to identify list nodes.\n" +
               "Example:\n" +
               "  (define r (open-json-file \"data.json\"))\n" +
               "  (json-next-object r) => next parsed JSON object";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String filename = new String(Value.asString(arguments[0]));
        if (!new File(filename).exists()) {
            throw new SchemeError(pos, name() + " ~a: file not found", filename);
        }
        try {
            Charset encoding = Encoding.getEncoding("utf8");
            var reader = new BufferedReader(new InputStreamReader(
                    new FileInputStream(filename),
                    encoding), 8192);
            var parser = new JsonParser(reader);
            if (arguments.length == 2) {
                if (Value.isSymbol(arguments[1])) {
                    parser.withListId(Value.asSymbol(arguments[1]));
                } else {
                    parser.withListId(new String(Value.asString(arguments[1])));
                }
            }
            return new NativeValue(parser);
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " ~a: io error", filename);
        }
    }
}
