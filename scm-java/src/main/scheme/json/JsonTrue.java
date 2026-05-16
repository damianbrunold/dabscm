package scheme.json;

public class JsonTrue extends JsonValue {

    public boolean isTrue() { return true; }

    @Override
    public String toString() {
        return "true";
    }
}
