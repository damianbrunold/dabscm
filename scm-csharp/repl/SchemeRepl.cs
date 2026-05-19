using scheme;
using System.Reflection;

namespace schemerepl;

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
            Scheme.CommandLineArgs = args;
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
                    var stdin = new TextStream(Console.In, "{stdin}");
                    var interactive = !Console.IsInputRedirected;
                    if (interactive) { Console.Write("> "); Console.Out.Flush(); }

                    while (true)
                    {
                        try
                        {
                            var expr = scheme.Read(stdin);
                            if (expr.Equals(Value.EOF)) break;
                            var value = scheme.Eval(expr);
                            Console.WriteLine(Value.PrintRep(value));
                        }
                        catch (SchemeError e)
                        {
                            e.PrintStackTrace();
                        }
                        if (interactive) { Console.Write("> "); Console.Out.Flush(); }
                    }
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
                    if (Value.IsInteger(result))
                    {
                        return (int) Value.AsInteger(result);
                    }
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                }
            }
            else
            {
                try
                {
                    var scheme = sysadmin ? Scheme.ForSysadmin() : Scheme.ForRepl();
                    var stdin = new TextStream(Console.In, "{stdin}");
                    var interactive = !Console.IsInputRedirected;
                    if (interactive) { Console.Write("> "); Console.Out.Flush(); }

                    while (true)
                    {
                        try
                        {
                            var expr = scheme.Read(stdin);
                            if (expr.Equals(Value.EOF)) break;
                            var value = scheme.Eval(expr);
                            Console.WriteLine(Value.PrintRep(value));
                        }
                        catch (SchemeError e)
                        {
                            e.PrintStackTrace();
                        }
                        if (interactive) { Console.Write("> "); Console.Out.Flush(); }
                    }
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
