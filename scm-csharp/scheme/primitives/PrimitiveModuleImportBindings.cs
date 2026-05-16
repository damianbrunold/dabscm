namespace scheme;

public class PrimitiveModuleImportBindings : Primitive
{
    private Modules modules;

    public PrimitiveModuleImportBindings(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%module-import-bindings";

    public override string Info() =>
        "Syntax: (%module-import-bindings module-dest module-src symbol ...)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Imports the given symbols from module-src's exports into module-dest's bindings. A symbol may be a (old-name new-name) pair for renaming.\n" +
        "Example:\n" +
        "  (%module-import-bindings '(my lib) '(scheme base) 'cons 'car 'cdr)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        var moduleDest = modules.GetModule(Modules.AsModuleName(arguments[0]));
        var moduleSrc = modules.GetModule(Modules.AsModuleName(arguments[1]));
        if (moduleDest != null && moduleSrc != null)
        {
            for (int i = 2; i < arguments.Length; i++)
            {
                string symbol;
                string rename;
                if (Value.IsPair(arguments[i]))
                {
                    symbol = Value.AsSymbol(Value.AsPair(arguments[i]).car);
                    rename = Value.AsSymbol(Value.AsPair(Value.AsPair(arguments[i]).cdr).car);
                }
                else
                {
                    symbol = Value.AsSymbol(arguments[i]);
                    rename = symbol;
                }
                var value = moduleSrc.Exports[symbol];
                var origin = moduleSrc.Provenance.GetValueOrDefault(symbol, moduleSrc.Name);
                moduleDest.ImportBinding(pos, rename, value, origin);
            }
            return Value.T;
        }
        return Value.F;
    }
}
