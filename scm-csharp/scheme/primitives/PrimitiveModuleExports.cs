namespace scheme;

public class PrimitiveModuleExports : Primitive
{
    private Modules modules;

    public PrimitiveModuleExports(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-exports";

    public override string Info() =>
        "Syntax: (%module-exports module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Returns an alphabetically sorted list of all symbols exported by the named module.\n" +
        "Example:\n" +
        "  (%module-exports '(scheme base))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var module = modules.GetModule(Modules.AsModuleName(arguments[0]));
        if (module == null)
        {
            throw new SchemeError(pos, Name() + ": module ~a not found", arguments[0]);
        }
        var symbols = module!.Exports.Keys.OrderBy(k => k).ToList();
        return Pair.List(symbols.Select(s => (object)Value.Intern(s)).ToArray());
    }
}
