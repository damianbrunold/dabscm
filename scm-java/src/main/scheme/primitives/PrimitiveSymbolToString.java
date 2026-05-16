package scheme.primitives;

import scheme.*;

public class PrimitiveSymbolToString extends Primitive {
    @Override
    public String name() {
        return "symbol->string";
    }

    @Override
    public String info() {
        return "Syntax: (symbol->string sym)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the name of sym as a string.\n" +
               "Example:\n" +
               "  (symbol->string 'hello) => \"hello\"\n" +
               "  (symbol->string 'foo-bar) => \"foo-bar\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.asSymbol(arguments[0]).toCharArray();
    }
}
