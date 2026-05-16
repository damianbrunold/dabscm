package scheme.primitives;

import scheme.*;

public class PrimitiveSymbolP extends Primitive {
    @Override
    public String name() {
        return "symbol?";
    }

    @Override
    public String info() {
        return "Syntax: (symbol? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a symbol, #f otherwise.\n" +
               "Example:\n" +
               "  (symbol? 'foo) => #t\n" +
               "  (symbol? \"foo\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isSymbol(arguments[0]);
    }
}
