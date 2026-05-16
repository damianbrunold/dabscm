package scheme.primitives;

import scheme.*;

public class PrimitiveBoundP extends Primitive {
    private Modules modules;

    public PrimitiveBoundP(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "bound?";
    }

    @Override
    public String info() {
        return "Syntax: (bound? symbol)\n" +
               "Library: (scm core)\n" +
               "Description: Returns #t if the given symbol is bound to a value in the current module.\n" +
               "Example:\n" +
               "  (bound? 'car) => #t\n" +
               "  (bound? 'undefined-name) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return modules.getCurrentModule().isBound(Value.asSymbol(arguments[0]));
    }
}
