using scheme;
using System.Reflection;

namespace schemerepl;

static class InteractiveRepl
{
    public static void Run(Scheme scheme)
    {
        var term = new Terminal();
        if (!term.CanRaw()) { RunCooked(scheme); return; }
        term.EnsureVt();
        string? histFile = HistoryPath();
        var history = new History(histFile);
        var provider = new SchemeCompletionProvider(scheme);
        var editor = new LineEditor(term, history, provider);
        while (true)
        {
            string? input;
            try { input = editor.ReadSexp("> "); }
            catch (Exception) { break; }
            if (input == null) break; // EOF
            if (string.IsNullOrWhiteSpace(input)) continue;
            try
            {
                var v = scheme.EvalString(input, "{stdin}");
                Console.WriteLine(Value.PrintRep(v));
            }
            catch (SchemeError e) { e.PrintStackTrace(); }
        }
    }

    public static void RunCooked(Scheme scheme)
    {
        var stdin = new TextStream(Console.In, "{stdin}");
        var interactive = !Console.IsInputRedirected;
        if (interactive) { Console.Write("> "); Console.Out.Flush(); }
        while (true)
        {
            try
            {
                var expr = scheme.Read(stdin);
                if (expr.Equals(Value.EOF)) break;
                var v = scheme.Eval(expr);
                Console.WriteLine(Value.PrintRep(v));
            }
            catch (SchemeError e) { e.PrintStackTrace(); }
            if (interactive) { Console.Write("> "); Console.Out.Flush(); }
        }
    }

    // REPL loop for Emacs/Geiser. Unlike RunCooked, the prompt is always
    // emitted (even when stdin is a pipe) because Geiser detects readiness by
    // matching the "> " prompt, and results are written with their machine
    // representation so Geiser can read the retort alist back.
    public static void RunGeiser(Scheme scheme)
    {
        var stdin = new TextStream(Console.In, "{stdin}");
        Console.Write("> "); Console.Out.Flush();
        while (true)
        {
            try
            {
                var expr = scheme.Read(stdin);
                if (expr.Equals(Value.EOF)) break;
                var v = scheme.Eval(expr);
                Console.WriteLine(Value.PrintRep(v));
            }
            catch (SchemeError e) { e.PrintStackTrace(); }
            Console.Out.Flush();
            Console.Write("> "); Console.Out.Flush();
        }
    }

    private static string? HistoryPath()
    {
        var custom = Environment.GetEnvironmentVariable("DABSCM_HISTORY");
        if (!string.IsNullOrEmpty(custom)) return custom;
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (string.IsNullOrEmpty(home)) return null;
        return Path.Combine(home, ".dabscm-history");
    }
}

class SchemeRepl
{
    static int Main(string[] args)
    {
        try
        {
            if (args.Contains("--strict"))
            {
                Scheme.StrictImports = true;
                args = args.Where(a => a != "--strict").ToArray();
            }
            bool sysadmin = args.Contains("--sysadmin");
            if (sysadmin)
            {
                args = args.Where(a => a != "--sysadmin").ToArray();
            }
            bool geiser = args.Contains("--geiser");
            if (geiser)
            {
                args = args.Where(a => a != "--geiser").ToArray();
            }
            Scheme.CommandLineArgs = args;
            if (geiser)
            {
                try
                {
                    var scheme = Scheme.ForRepl();
                    scheme.EvalString("(import (scm geiser))", "{geiser}");
                    InteractiveRepl.RunGeiser(scheme);
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                }
                return 0;
            }
            if (args.Length > 0 && (args[0] == "--version" || args[0] == "-v"))
            {
                var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "unknown";
                Console.WriteLine(version);
                return 0;
            }
            if (args.Length >= 2 && args[0] == "-e")
            {
                try
                {
                    var scheme = Scheme.ForMinimal();
                    var result = scheme.EvalString(args[1], "{-e}");
                    Console.WriteLine(Value.PrintRep(result));
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                    return 1;
                }
                return 0;
            }
            else if (args.Length >= 2 && args[0] == "-b")
            {
                try
                {
                    var scheme = Scheme.ForProgram();
                    var result = scheme.EvalString(args[1], "{-b}");
                    Console.WriteLine(Value.PrintRep(result));
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                    return 1;
                }
                return 0;
            }
            else if (args.Length >= 2 && args[0] == "-f")
            {
                try
                {
                    var scheme = Scheme.ForRepl();
                    var result = scheme.EvalString(args[1], "{-f}");
                    Console.WriteLine(Value.PrintRep(result));
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                    return 1;
                }
                return 0;
            }
            else if (args.Length == 1 &&
                     (args[0] == "-e" || args[0] == "-b" || args[0] == "-f"))
            {
                try
                {
                    Scheme scheme;
                    if (args[0] == "-f") scheme = Scheme.ForRepl();
                    else if (args[0] == "-b") scheme = Scheme.ForProgram();
                    else scheme = Scheme.ForMinimal();
                    InteractiveRepl.Run(scheme);
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                }
            }
            else if (args.Length > 0)
            {
                try
                {
                    var script = args[0];
                    var scheme = sysadmin ? Scheme.ForSysadmin() : Scheme.ForProgram();
                    object arguments = Value.NIL;
                    for (int i = args.Length - 1; i >= 1; i--)
                    {
                        arguments = new Pair(args[i].ToCharArray(), arguments);
                    }
                    scheme.Bind("script-name", script.ToCharArray());
                    scheme.Bind("script-arguments", arguments);
                    var result = scheme.EvalFile(script);
                    //scheme.DumpCallCounts();
                    // A deferred exit code (set via set-exit-code!) takes
                    // precedence so a script can signal failure without
                    // terminating; otherwise an integer result is the code.
                    if (Scheme.PendingExitCode != 0)
                    {
                        return Scheme.PendingExitCode;
                    }
                    if (Value.IsInteger(result))
                    {
                        return (int) Value.AsInteger(result);
                    }
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                    return 1;
                }
            }
            else
            {
                try
                {
                    var scheme = sysadmin ? Scheme.ForSysadmin() : Scheme.ForRepl();
                    InteractiveRepl.Run(scheme);
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                }
            }

            return 0;
        }
        finally
        {
            Console.Out.Flush();
        }
    }
}
