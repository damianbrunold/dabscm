namespace scheme;

public class PrimitiveModuleRef : Primitive
{
    private Modules modules;

    public PrimitiveModuleRef(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-ref";

    public override string Info() =>
        "Syntax: (%module-ref module-name symbol)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the value bound to symbol in the named module. Raises an error if the symbol is not bound.\n" +
        "Example:\n" +
        "  (%module-ref '(scheme base) 'car)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var module = modules.GetModuleRequired(pos, Modules.AsModuleName(arguments[0]));
        var symbol = Value.AsSymbol(arguments[1]);
        return module.Resolve(pos, symbol);
    }
}
