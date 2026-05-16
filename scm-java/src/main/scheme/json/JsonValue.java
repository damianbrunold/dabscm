package scheme.json;

public abstract class JsonValue {

    public boolean isFalse() { return false; }
    public boolean isTrue() { return false; }
    public boolean isNull() { return false; }
    public boolean isNumber() { return false; }
    public boolean isString() { return false; }
    public boolean isList() { return false; }
    public boolean isObject() { return false; }

    public JsonString asString() { return (JsonString) this; }
    public JsonNumber asNumber() { return (JsonNumber) this; }
    public JsonList asList() { return (JsonList) this; }
    public JsonObject asObject() { return (JsonObject) this; }

}
