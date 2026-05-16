package scheme.primitives;

import scheme.*;
import scheme.json.JsonParser;

public class PrimitiveJsonNextObject extends Primitive {
    @Override
    public String name() {
        return "json-next-object";
    }

    @Override
    public String info() {
        return "Syntax: (json-next-object reader)\n" +
               "Library: (scm core)\n" +
               "Description: Reads and returns the next JSON object from the given JSON reader, or #f if there are no more objects.\n" +
               "Example:\n" +
               "  (let ((r (open-json-file \"data.json\")))\n" +
               "    (json-next-object r))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            JsonParser reader = (JsonParser) Value.asNativeValue(arguments[0]).value;
            var result = reader.nextObject();
            if (result == null) {
                return Value.F;
            }
            return new NativeValue(result);
        } catch (Exception e) {
            throw new SchemeError(pos, "json-next-object failed: ~s", e.getMessage());
        }
    }
}
