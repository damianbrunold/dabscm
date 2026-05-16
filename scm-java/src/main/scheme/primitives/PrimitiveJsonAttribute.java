package scheme.primitives;

import scheme.*;
import scheme.json.JsonObject;
import scheme.json.JsonValue;

public class PrimitiveJsonAttribute extends Primitive {
    @Override
    public String name() {
        return "json-attribute";
    }

    @Override
    public String info() {
        return "Syntax: (json-attribute object name) (json-attribute object name default)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the value of the named attribute from a JSON object. Returns default (or #f) if the attribute does not exist.\n" +
               "Example:\n" +
               "  (let ((obj (json-next-object reader)))\n" +
               "    (json-attribute obj 'name \"unknown\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        try {
            JsonObject obj = (JsonObject) Value.asNativeValue(arguments[0]).value;
            String name;
            if (Value.isSymbol(arguments[1])) {
                name = Value.asSymbol(arguments[1]);
            } else {
                name = new String(Value.asString(arguments[1]));
            }
            if (arguments.length == 3) {
                if (obj.entries.containsKey(name)) {
                    return toScm(obj.entries.get(name));
                }
                return arguments[2];
            } else {
                if (obj.entries.containsKey(name)) {
                    return toScm(obj.entries.get(name));
                }
                return Value.F;
            }
        } catch (Exception e) {
            throw new SchemeError(pos, "json-attribute failed: ~s", e.getMessage());
        }
    }

    private Object toScm(JsonValue value) {
        if (value.isString()) {
            return value.asString().value.toCharArray();
        } else if (value.isFalse()) {
            return Value.F;
        } else if (value.isTrue()) {
            return Value.T;
        } else if (value.isNull()) {
            return Value.NIL;
        } else if (value.isNumber()) {
            double val = value.asNumber().value;
            if (val == ((double) ((long) val))) {
                return (long) val;
            } else {
                return val;
            }
        } else if (value.isObject()) {
            return new NativeValue(value);
        } else if (value.isList()) {
            var list = new Object[value.asList().elements.size()];
            for (var i = 0; i < value.asList().elements.size(); i++) {
                list[i] = toScm(value.asList().elements.get(i));
            }
            return Pair.list(list);
        }
        return Value.F;
    }
}
