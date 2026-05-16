package scheme.json;

import java.util.LinkedHashMap;
import java.util.Map;

public class JsonObject extends JsonValue {

    public Map<String, JsonValue> entries = new LinkedHashMap<>();

    public boolean isObject() { return true; }

    public String getString(String name, String defaultValue) {
        if (!entries.containsKey(name)) return defaultValue;
        return entries.get(name).asString().value;
    }

    public String getString(String name) {
        if (!entries.containsKey(name)) return "";
        return entries.get(name).asString().value;
    }

    public double getNumber(String name, double defaultValue) {
        if (!entries.containsKey(name)) return defaultValue;
        return entries.get(name).asNumber().value;
    }

    public int getInt(String name, int defaultValue) {
        if (!entries.containsKey(name)) return defaultValue;
        return (int) entries.get(name).asNumber().value;
    }

    public boolean getBoolean(String name, boolean defaultValue) {
        if (!entries.containsKey(name)) return defaultValue;
        if (entries.get(name).isTrue()) return true;
        return false;
    }

    @Override
    public String toString() {
        StringBuilder result = new StringBuilder("{");
        if (!entries.isEmpty()) {
            for (String name : entries.keySet()) {
                result.append("\"" + name.replace("\\", "\\\\").replace("\"", "\\\"") + "\": ");
                result.append(entries.get(name));
                result.append(", ");
            }
            result.setLength(result.length() - 2);
        }
        result.append("}");
        return result.toString();
    }
}
