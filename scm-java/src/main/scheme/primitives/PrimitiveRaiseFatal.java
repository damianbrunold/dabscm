package scheme.primitives;

import scheme.*;

public class PrimitiveRaiseFatal extends Primitive {
    @Override
    public String name() { return "%raise-fatal"; }

    @Override
    public String info() {
        return "Syntax: (%raise-fatal condition)\n" +
               "Library: (scm core)\n" +
               "Description: Raises condition as a fatal error, bypassing all Scheme-level exception handlers. Used internally by the VM's default top-level error handler.\n" +
               "Example:\n" +
               "  (%raise-fatal (make-error-object \"fatal\" '()))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        Object condition = args[0];
        if (condition instanceof ErrorObject) {
            throw new SchemeError(pos, (ErrorObject) condition);
        } else {
            throw new SchemeError(pos, new ErrorObject(Value.displayRep(condition), new Object[0]));
        }
    }
}
