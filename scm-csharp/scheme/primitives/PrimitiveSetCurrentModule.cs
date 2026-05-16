namespace scheme;

public class PrimitiveSetCurrentModule : Primitive
{
    private Modules modules;

    public PrimitiveSetCurrentModule(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "set-current-module";

    public override string Info() =>
        "Syntax: (set-current-module module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Sets the specified module as the active module. Subsequent definitions will be made in that module.\n" +
        "Example:\n" +
        "  (set-current-module '(scm core))\n" +
        "  (current-module) => (scm core)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        modules.SetCurrentModule(Modules.AsModuleName(arguments[0]));
        return Value.T;
    }
}
