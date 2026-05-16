namespace scheme;

public class PrimitiveBoundP : Primitive
{
    private Modules modules;

    public PrimitiveBoundP(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "bound?";
    }

    public override string Info()
    {
        return
            "Syntax: (bound? symbol)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if the given symbol is bound to a value in the current module.\n" +
            "Example:\n" +
            "  (bound? 'car) => #t\n" +
            "  (bound? 'undefined-name) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return modules.GetCurrentModule().IsBound(Value.AsSymbol(arguments[0]));
    }
}
