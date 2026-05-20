using scheme;

namespace schemerepl;

public sealed class SchemeCompletionProvider : ICompletionProvider
{
    private readonly Scheme scheme;
    private bool enabled = true;

    public SchemeCompletionProvider(Scheme scheme)
    {
        this.scheme = scheme;
        try { scheme.EvalString("(import (scm repl))", "<repl-bootstrap>"); }
        catch { enabled = false; }
    }

    public IList<string> Completions(string prefix)
    {
        if (!enabled || prefix == null) return Array.Empty<string>();
        try
        {
            scheme.Bind("__repl-arg", prefix.ToCharArray());
            var r = scheme.EvalString("(repl-completions __repl-arg)", "<repl-tab>");
            return AsStringList(r);
        }
        catch { return Array.Empty<string>(); }
    }

    public string InfoLine(string name)
    {
        if (!enabled || string.IsNullOrEmpty(name)) return "";
        try
        {
            scheme.Bind("__repl-arg", name.ToCharArray());
            var r = scheme.EvalString("(repl-info-line __repl-arg)", "<repl-info>");
            return AsString(r);
        }
        catch { return ""; }
    }

    private static List<string> AsStringList(object? o)
    {
        var list = new List<string>();
        while (o is Pair p)
        {
            list.Add(AsString(p.car));
            o = p.cdr;
        }
        return list;
    }

    private static string AsString(object? o)
    {
        if (o == null) return "";
        if (o is char[] ca) return new string(ca);
        if (o is string s) return s;
        return Value.PrintRep(o);
    }
}
