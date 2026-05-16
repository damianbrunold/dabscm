package scheme.primitives;

import scheme.Modules;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveModuleRef extends Primitive {
    private Modules modules;

    public PrimitiveModuleRef(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%module-ref";
    }

    @Override
    public String info() {
        return "Syntax: (%module-ref module-name symbol)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the value bound to symbol in the named module. Raises an error if the symbol is not bound.\n" +
               "Example:\n" +
               "  (%module-ref '(scheme base) 'car)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var module = modules.getModuleRequired(pos, Modules.asModuleName(arguments[0]));
        var symbol = Value.asSymbol(arguments[1]);
        return module.resolve(pos, symbol);
    }
}
