package scheme.json;

public class JsonFalse extends JsonValue {

    public boolean isFalse() { return true; }

    @Override
    public String toString() {
        return "false";
    }
}
