package scheme.primitives;

import scheme.Primitive;
import scheme.Primitives;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitivePrimitive extends Primitive {
    private Primitives primitives;

    public PrimitivePrimitive(Primitives primitives) {
        this.primitives = primitives;
    }

    @Override
    public String name() {
        return "%primitive";
    }

    @Override
    public String info() {
        return "Syntax: (%primitive symbol)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the built-in primitive procedure named by symbol. Used internally by library files to bind C# primitives.\n" +
               "Example:\n" +
               "  (%primitive 'car) => #<primitive car>\n" +
               "  (%primitive \"cons\") => #<primitive cons>";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String name = Value.isSymbol(arguments[0])
            ? Value.asSymbol(arguments[0])
            : new String(Value.asString(arguments[0]));
        return primitives.getPrimitive(pos, name);
    }
}
