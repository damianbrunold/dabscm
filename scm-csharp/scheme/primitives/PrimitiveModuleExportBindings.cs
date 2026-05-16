namespace scheme;

public class PrimitiveModuleExportBindings : Primitive
{
    private Modules modules;

    public PrimitiveModuleExportBindings(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-export-bindings";

    public override string Info() =>
        "Syntax: (%module-export-bindings module-name symbol ...)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Marks the given symbols as exported from the named module. Each symbol must already be bound in the module.\n" +
        "Example:\n" +
        "  (%module-export-bindings '(my lib) 'foo 'bar)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        var moduleName = Modules.AsModuleName(arguments[0]);
        var module = modules.GetModule(moduleName);
        if (module != null)
        {
            for (int i = 1; i < arguments.Length; i++)
            {
                var symbol = Value.AsSymbol(arguments[i]);
                if (!module.Bindings.TryGetValue(symbol, out var binding))
                    throw new SchemeError(pos, "library '~s': cannot export '~s': not defined or imported", moduleName, symbol);
                module.Exports[symbol] = binding;
            }
            return Value.T;
        }
        return Value.F;
    }
}
