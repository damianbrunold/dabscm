package scheme.json;

public class JsonNumber extends JsonValue {

    public double value;

    public JsonNumber(double value) {
        this.value = value;
    }

    public boolean isNumber() { return true; }

    @Override
    public String toString() {
        if (value == Math.floor(value)) return Integer.toString((int) value);
        return Double.toString(value);
    }
}
