package scheme.primitives;

import scheme.Parameter;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveMakeParameterCore extends Primitive {
    @Override
    public String name() { return "%make-parameter"; }

    @Override
    public String info() {
        return "Syntax: (%make-parameter init)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Returns a fresh parameter object with `init` as its default value. The returned object is callable: zero args reads the calling thread's current value (defaulting to `init`), one arg sets it. The Scheme-level make-parameter wraps this to apply an optional converter.\n" +
               "Example:\n" +
               "  (define p (%make-parameter 10))\n" +
               "  (p)     => 10\n" +
               "  (p 20)\n" +
               "  (p)     => 20";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return new Parameter(arguments[0]);
    }
}
