package scheme;

import java.util.Arrays;
import java.util.stream.Collectors;

public class ErrorObject {
    public final String message;
    public final Object[] irritants;

    public ErrorObject(String message, Object[] irritants) {
        this.message = message;
        this.irritants = irritants;
    }

    @Override
    public String toString() {
        if (irritants.length == 0) return message;
        return message + ": " + Arrays.stream(irritants)
            .map(Value::printRep)
            .collect(Collectors.joining(", "));
    }
}
