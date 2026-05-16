namespace scheme;

public class SchemeCallFrame
{
    public string? name;
    public SourcePos? pos;

    public SchemeCallFrame(string? name, SourcePos? pos)
    {
        this.name = name;
        this.pos = pos;
    }

    public override string ToString()
    {
        string n = name ?? "?";
        return pos != null ? "  at " + n + " (" + pos + ")" : "  at " + n;
    }
}
