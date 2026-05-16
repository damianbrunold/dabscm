package scheme.primitives;

import scheme.*;

public class PrimitiveSysScmTechnology extends Primitive {
    @Override public String name() { return "sys-scm-technology"; }

    @Override public String info() {
        return "Syntax: (sys-scm-technology)\n" +
               "Library: (scm system)\n" +
               "Description: Returns a symbol identifying the SCM implementation technology: csharp or java.\n" +
               "Example:\n" +
               "  (sys-scm-technology) => java";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return Value.intern("java");
    }
}
