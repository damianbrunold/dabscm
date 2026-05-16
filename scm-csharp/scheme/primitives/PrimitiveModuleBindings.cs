namespace scheme;

public class PrimitiveModuleBindings : Primitive
{
    private Modules modules;

    public PrimitiveModuleBindings(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-bindings";

    public override string Info() =>
        "Syntax: (%module-bindings module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Returns an alphabetically sorted list of all symbols bound in the named module.\n" +
        "Example:\n" +
        "  (%module-bindings '(scheme base))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var module = modules.GetModule(Modules.AsModuleName(arguments[0]));
        if (module == null)
        {
            throw new SchemeError(pos, Name() + ": module ~a not found", arguments[0]);
        }
        var symbols = module!.Bindings.Keys.OrderBy(k => k).ToList();
        return Pair.List(symbols.Select(s => (object)Value.Intern(s)).ToArray());
    }
}
