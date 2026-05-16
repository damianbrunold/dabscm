namespace scheme;

public class PrimitiveLoad : Primitive
{
    private readonly Modules modules;

    public PrimitiveLoad(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "load";

    public override string Info() =>
        "Syntax: (load filename) (load filename environment)\n" +
        "Library: (scheme load)\n" +
        "Description: Reads and evaluates all expressions from the named Scheme source file. If an environment is given, evaluates in that module's environment.\n" +
        "Example:\n" +
        "  (load \"mylib.scm\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string filename = new string(Value.AsString(arguments[0]));
        try
        {
            Modules evalModules = modules;
            if (arguments.Length == 2)
            {
                var moduleName = Modules.AsModuleName(arguments[1]);
                var module = modules.GetModule(moduleName);
                if (module == null)
                {
                    var loadModule = (Primitive)modules.GetModuleRequired(pos, "scm core").Resolve(pos, "%load-module");
                    loadModule.Apply(pos, new object[] { arguments[1] });
                    module = modules.GetModule(moduleName);
                }
                if (module == null)
                    throw new SchemeError(pos, "load: environment not found: ~a", moduleName);
                evalModules = new Modules(modules, module);
            }
            new Scheme(evalModules).EvalFile(filename);
            return Value.T;
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "load: cannot open '~a': ~a", filename, e.Message);
        }
    }
}
