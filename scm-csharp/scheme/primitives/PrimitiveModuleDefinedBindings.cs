namespace scheme;

public class PrimitiveModuleDefinedBindings : Primitive
{
    private Modules modules;

    public PrimitiveModuleDefinedBindings(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-defined-bindings";

    public override string Info() =>
        "Syntax: (%module-defined-bindings module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Returns an alphabetically sorted list of all symbols\n" +
        "defined (not imported) in the named module. A symbol is considered\n" +
        "defined if its provenance matches the module's own name.\n" +
        "Example:\n" +
        "  (%module-defined-bindings '(scheme base))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var module = modules.GetModule(Modules.AsModuleName(arguments[0]));
        var symbols = module!.Bindings.Keys
            .Where(k => module.Provenance.TryGetValue(k, out var origin) && origin == module.Name)
            .OrderBy(k => k).ToList();
        return Pair.List(symbols.Select(s => (object)Value.Intern(s)).ToArray());
    }
}
