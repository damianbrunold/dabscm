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
            for (int i = 0; i < arguments.Length; i++)
            {
                string filename = new string(Value.AsString(arguments[i]));
                scheme.EvalFile(filename);
            }
            return new Values();
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
}
