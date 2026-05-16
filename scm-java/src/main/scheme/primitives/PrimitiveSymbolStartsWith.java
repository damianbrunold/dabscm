package scheme.primitives;

import scheme.*;

public class PrimitiveSymbolStartsWith extends Primitive {
    @Override
    public String name() {
        return "symbol-starts-with?";
    }

    @Override
    public String info() {
        return "Syntax: (symbol-starts-with? sym str)\n" +
               "Library: (scm string)\n" +
               "Description: Returns #t if the string representation of sym starts with str, #f otherwise. str may be a string or a symbol.\n" +
               "Example:\n" +
               "  (symbol-starts-with? 'foobar \"foo\") => #t\n" +
               "  (symbol-starts-with? 'foobar \"bar\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        String str = Value.asSymbol(arguments[0]);
	String prefix;
        if (Value.isSymbol(arguments[1])) {
            prefix = Value.asSymbol(arguments[1]);
        } else {
            prefix = new String(Value.asString(arguments[1]));
        }
	return str.startsWith(prefix);
    }
}
