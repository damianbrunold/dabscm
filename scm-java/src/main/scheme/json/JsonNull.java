package scheme.json;

public class JsonNull extends JsonValue {

    public boolean isNull() { return true; }

    @Override
    public String toString() {
        return "null";
    }
}
