package scheme.primitives;

import scheme.*;

// (%primitive-name obj): the name of a primitive procedure as a symbol, #f
// for anything else. (srfi 69)/(srfi 125) recognize the equivalences a
// hash table supports by it: a primitive need not be eq? to itself across
// libraries (in dabscm native it is not).
public class PrimitivePrimitiveName extends Primitive {
    @Override
    public String name() { return "%primitive-name"; }

    @Override
    public String info() { return ""; }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isPrimitive(arguments[0]))
            return Value.intern(Value.asPrimitive(arguments[0]).name());
        return Value.F;
    }
}
