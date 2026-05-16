package scheme;

public class NativeValue {
    public Object value;

    public NativeValue(Object value) {
        this.value = value;
    }
    
    public String toString() {
        return value.toString();
    }
}
