package scheme;

/**
 * A cast failure that knows the offending value. It is a
 * ClassCastException, so the VM and the primitive call sites still turn it
 * into "Failed in &lt;name&gt;: wrong argument type", now with the value as
 * irritant.
 */
public class WrongTypeException extends ClassCastException {
    public final transient Object value;
    public final String expected;

    public WrongTypeException(Object value, String expected) {
        super("expected " + expected);
        this.value = value;
        this.expected = expected;
    }

    // A boxed Java number that is no Scheme number (Scheme integers are Long),
    // typically a primitive that returned an int by mistake.
    public static boolean isHostValue(Object v) {
        return v instanceof Integer || v instanceof Short || v instanceof Byte
            || v instanceof Float || v instanceof java.math.BigDecimal;
    }
}
