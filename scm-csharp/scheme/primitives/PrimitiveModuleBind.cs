namespace scheme;

public class PrimitiveModuleBind : Primitive
{
    private Modules modules;

    public PrimitiveModuleBind(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-bind";

    public override string Info() =>
        "Syntax: (%module-bind module-name symbol value)\n" +
        "Library: (scm core)\n" +
        "Description: Binds or rebinds symbol to value in the named module, bypassing import checks. If the symbol is exported, the export is updated too.\n" +
        "Example:\n" +
        "  (%module-bind '(scheme base) 'car new-car-impl)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        var module = modules.GetModuleRequired(pos, Modules.AsModuleName(arguments[0]));
        var symbol = Value.AsSymbol(arguments[1]);
        var value = arguments[2];
        var origin = module.Provenance.GetValueOrDefault(symbol, module.Name);
        module.Bind(symbol, value, origin);
        if (module.Exports.ContainsKey(symbol))
        {
            module.Exports[symbol] = value;
        }
        return Value.T;
    }
}
