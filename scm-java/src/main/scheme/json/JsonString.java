package scheme.json;

public class JsonString extends JsonValue {

    public String value;

    public JsonString(String value) {
        this.value = value;
    }

    public boolean isString() { return true; }

    @Override
    public String toString() {
        return "\"" + value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r") + "\"";
    }
}
