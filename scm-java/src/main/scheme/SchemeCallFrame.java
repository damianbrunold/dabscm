package scheme;

public class SchemeCallFrame {
    public String name;
    public SourcePos pos;

    public SchemeCallFrame(String name, SourcePos pos) {
        this.name = name;
        this.pos = pos;
    }

    @Override
    public String toString() {
        String n = name != null ? name : "?";
        return pos != null ? "  at " + n + " (" + pos + ")" : "  at " + n;
    }
}
