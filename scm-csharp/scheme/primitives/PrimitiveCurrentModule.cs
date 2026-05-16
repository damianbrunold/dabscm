namespace scheme;

public class PrimitiveCurrentModule : Primitive
{
    private Modules modules;

    public PrimitiveCurrentModule(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "current-module";

    public override string Info() =>
        "Syntax: (current-module)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the name declaration of the current module.\n" +
        "Example:\n" +
        "  (current-module) => (user main)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return modules.GetCurrentModule().Decl;
    }
}
