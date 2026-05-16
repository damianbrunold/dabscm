package scheme.json;

import java.util.ArrayList;
import java.util.List;

public class JsonList extends JsonValue {

    public List<JsonValue> elements = new ArrayList<>();

    public boolean isList() { return true; }

    @Override
    public String toString() {
        StringBuilder result = new StringBuilder("[");
        if (!elements.isEmpty()) {
            for (int i = 0; i < elements.size() - 1; i++) {
                result.append(elements.get(i)).append(", ");
            }
            result.append(elements.get(elements.size() - 1));
        }
        result.append("]");
        return result.toString();
    }
}
