using System.Text;

namespace schemerepl;

public sealed class History
{
    private const int Cap = 1000;
    private readonly string? file;
    private readonly List<string> entries = new();

    public History(string? file)
    {
        this.file = file;
        Load();
    }

    public int Count => entries.Count;
    public string Get(int i) => entries[i];

    public void Add(string entry)
    {
        if (string.IsNullOrEmpty(entry)) return;
        if (entries.Count > 0 && entries[^1] == entry) return;
        entries.Add(entry);
        while (entries.Count > Cap) entries.RemoveAt(0);
        AppendToFile(entry);
    }

    public int SearchBackward(string q, int from)
    {
        if (q.Length == 0) return from;
        int start = Math.Min(from - 1, entries.Count - 1);
        for (int i = start; i >= 0; i--)
            if (entries[i].Contains(q)) return i;
        return -1;
    }

    public int SearchForward(string q, int from)
    {
        if (q.Length == 0) return -1;
        for (int i = Math.Max(from + 1, 0); i < entries.Count; i++)
            if (entries[i].Contains(q)) return i;
        return -1;
    }

    private void Load()
    {
        if (file == null || !File.Exists(file)) return;
        try
        {
            foreach (var line in File.ReadAllLines(file))
                entries.Add(Decode(line));
            while (entries.Count > Cap) entries.RemoveAt(0);
        }
        catch { }
    }

    private void AppendToFile(string entry)
    {
        if (file == null) return;
        try
        {
            var dir = Path.GetDirectoryName(file);
            if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
            File.AppendAllText(file, Encode(entry) + "\n");
        }
        catch { }
    }

    internal static string Encode(string s)
    {
        var sb = new StringBuilder(s.Length + 8);
        foreach (char c in s)
        {
            if (c == '\n') sb.Append('\t').Append('n');
            else if (c == '\t') sb.Append('\t').Append('t');
            else sb.Append(c);
        }
        return sb.ToString();
    }

    internal static string Decode(string s)
    {
        var sb = new StringBuilder(s.Length);
        for (int i = 0; i < s.Length; i++)
        {
            char c = s[i];
            if (c == '\t' && i + 1 < s.Length)
            {
                char n = s[i + 1];
                if (n == 'n') { sb.Append('\n'); i++; continue; }
                if (n == 't') { sb.Append('\t'); i++; continue; }
            }
            sb.Append(c);
        }
        return sb.ToString();
    }
}
