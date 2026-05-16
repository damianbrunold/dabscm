namespace scheme;

public class PrimitiveCreateModule : Primitive
{
    private Modules modules;

    public PrimitiveCreateModule(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%create-module";

    public override string Info() =>
        "Syntax: (%create-module module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Creates the named module if it does not already exist. Returns the module name.\n" +
        "Example:\n" +
        "  (create-module '(my lib))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var oldModule = modules.GetCurrentModule();
        modules.SetCurrentModule(Modules.AsModuleName(arguments[0]));
        modules.SetCurrentModule(oldModule.Name);
        return arguments[0];
    }
}
