namespace scheme;

public class PrimitiveResetModules : Primitive
{
    private Modules modules;

    public PrimitiveResetModules(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%reset-modules";

    public override string Info() =>
        "Syntax: (%reset-modules)\n" +
        "Library: (scm core)\n" +
        "Description: Clears all loaded modules except scm core, forcing libraries to be re-imported on next use. Used for testing and development.\n" +
        "Example:\n" +
        "  (%reset-modules)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        modules.ResetModules();
        var scm_core = modules.GetModuleRequired(pos, "scm core");
        modules.UpdateModuleVar();
        return Value.T;
    }
}
