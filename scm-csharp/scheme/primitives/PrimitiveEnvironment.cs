namespace scheme;

public class PrimitiveEnvironment : Primitive
{
    private readonly Modules modules;
    private static int counter = 0;

    public PrimitiveEnvironment(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "environment";

    public override string Info() =>
        "Syntax: (environment lib ...)\n" +
        "Library: (scheme eval)\n" +
        "Description: Returns an environment specifier suitable for use with eval. Each lib must be a library name. With no arguments, returns the scm core environment.\n" +
        "Example:\n" +
        "  (eval '(+ 1 2) (environment '(scheme base))) => 3";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, -1);

        // No args: return scm core
        if (arguments.Length == 0)
        {
            return "scm core".ToCharArray();
        }

        // Single lib: ensure it is loaded and return it as-is for eval to use
        if (arguments.Length == 1)
        {
            var moduleName = Modules.AsModuleName(arguments[0]);
            if (modules.GetModule(moduleName) == null)
            {
                var loadModule = (Primitive)modules.GetModuleRequired(pos, "scm core").Resolve(pos, "%load-module");
                loadModule.Apply(pos, new object[] { arguments[0] });
            }
            return arguments[0];
        }

        // Multiple libs: create a fresh composite module and import all libs into it
        string name = "%environment-" + (System.Threading.Interlocked.Increment(ref counter));
        var originalModule = modules.GetCurrentModule();
        try
        {
            modules.SetCurrentModule(name);  // creates module if needed
            var importSet = new PrimitiveDoImportSet(modules);
            foreach (var arg in arguments)
            {
                importSet.Apply(pos, new object[] { arg });
            }
        }
        finally
        {
            modules.SetCurrentModule(originalModule.Name);
        }
        return name.ToCharArray();
    }
}
