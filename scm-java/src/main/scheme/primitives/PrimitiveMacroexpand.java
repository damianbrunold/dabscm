package scheme.primitives;

import scheme.*;

public class PrimitiveMacroexpand extends Primitive {
    private final Modules modules;

    public PrimitiveMacroexpand(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() { return "macroexpand"; }

    @Override
    public String info() {
        return "Syntax: (macroexpand expr)\n" +
               "Library: (scm core)\n" +
               "Description: Fully expands all macros in expr using the Dybvig expander.\n" +
               "Returns a plain S-expression with all macros expanded.\n" +
               "Example:\n" +
               "  (macroexpand '(and 1 2 3)) => (if 1 (and 2 3) #f)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Expander expander = new Expander(modules);
        Object expanded = expander.expand(
            pos != null ? pos : new SourcePos("<macroexpand>", 0, 0),
            arguments[0]);
        return SyntaxObject.strip(expanded);
    }
}
