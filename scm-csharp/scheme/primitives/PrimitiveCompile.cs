namespace scheme;

public class PrimitiveCompile : Primitive
{
    private Modules modules;

    public PrimitiveCompile(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "compile";
    }

    public override string Info()
    {
        return
            "Syntax: (compile expr)\n" +
            "Library: (scm compile)\n" +
            "Description: Compiles the given Scheme expression to a bytecode instruction vector without evaluating it.\n" +
            "Example:\n" +
            "  (compile '(+ 1 2)) => #(...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Compiler compiler = new Compiler(modules);
        object result = compiler.Compile(null, arguments[0]); // TODO set pos
        return result;
    }
}
