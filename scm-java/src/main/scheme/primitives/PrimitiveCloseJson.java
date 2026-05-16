package scheme.primitives;

import scheme.*;
import scheme.json.JsonParser;

public class PrimitiveCloseJson extends Primitive {
    @Override
    public String name() {
        return "close-json";
    }

    @Override
    public String info() {
        return "Syntax: (close-json reader)\n" +
               "Library: (scm core)\n" +
               "Description: Closes the given JSON reader, releasing any underlying resources.\n" +
               "Example:\n" +
               "  (let ((r (open-json-file \"data.json\")))\n" +
               "    (close-json r))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            JsonParser reader = (JsonParser) Value.asNativeValue(arguments[0]).value;
            reader.close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "close-json failed: ~s", e.getMessage());
        }
    }
}
