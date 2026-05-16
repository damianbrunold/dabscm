package scheme.primitives;

import scheme.*;

public class PrimitiveGensym extends Primitive {
    private static int counter = 1;

    @Override
    public String name() {
        return "gensym";
    }

    @Override
    public String info() {
        return "Syntax: (gensym)\n" +
               "Library: (scm core)\n" +
               "Description: Returns a fresh, unique, non-interned symbol. Each call returns a symbol distinct from all previously generated symbols.\n" +
               "Example:\n" +
               "  (gensym) => gensym-1\n" +
               "  (eq? (gensym) (gensym)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        // do not intern the symbol to ensure unique symbol!
        return "gensym-" + counter++;
    }
}
