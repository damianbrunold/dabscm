package scheme.primitives;

import scheme.*;

public class PrimitiveCompile extends Primitive {
    private Modules modules;

    public PrimitiveCompile(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "compile";
    }

    @Override
    public String info() {
        return "Syntax: (compile expr)\n" +
               "Library: (scm compile)\n" +
               "Description: Compiles the given Scheme expression to a bytecode instruction vector without evaluating it.\n" +
               "Example:\n" +
               "  (compile '(+ 1 2)) => #(...)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Compiler compiler = new Compiler(modules);
        Object result = compiler.compile(pos, arguments[0]);
        return result;
    }
}
