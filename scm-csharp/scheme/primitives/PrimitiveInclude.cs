namespace scheme;

public class PrimitiveInclude : Primitive
{
    private Modules modules;

    public PrimitiveInclude(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "include";

    public override string Info() =>
        "Syntax: (include filename ...)\n" +
        "Library: (scheme base)\n" +
        "Description: Loads and evaluates one or more Scheme source files in the current module's environment.\n" +
        "Example:\n" +
        "  (include \"helpers.scm\" \"utils.scm\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        try
        {
            Scheme scheme = new Scheme(modules);
            object value = new Values();
            for (int i = 0; i < arguments.Length; i++)
            {
                string filename = new string(Value.AsString(arguments[i]));
                value = scheme.EvalFile(Resolve(pos, filename));
            }
            // the value of the last form, as where the forms stood
            return value;
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, Name() + ": io failure");
        }
    }

    // A relative name resolves against the directory of the file with the
    // include (as the native implementation and library declarations do),
    // else the current directory
    internal static string Resolve(SourcePos? pos, string filename)
    {
        if (Path.IsPathRooted(filename)) return filename;
        if (pos != null && !string.IsNullOrEmpty(pos.filename))
        {
            string? dir = Path.GetDirectoryName(Path.GetFullPath(pos.filename));
            if (dir != null)
            {
                string candidate = Path.Combine(dir, filename);
                if (File.Exists(candidate)) return candidate;
            }
        }
        return filename;
    }
}
