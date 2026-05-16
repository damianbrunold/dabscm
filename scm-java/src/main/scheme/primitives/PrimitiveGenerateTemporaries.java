package scheme.primitives;

import scheme.*;

import java.util.concurrent.atomic.AtomicInteger;

public class PrimitiveGenerateTemporaries extends Primitive {
    private static final AtomicInteger counter = new AtomicInteger(1);

    @Override
    public String name() { return "generate-temporaries"; }

    @Override
    public String info() {
        return "Syntax: (generate-temporaries list)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a list of fresh identifiers (syntax objects wrapping unique symbols), " +
               "one for each element of list. The identifiers are guaranteed to be distinct from all " +
               "other identifiers. Used in syntax-case transformers for hygienic macro expansion.\n" +
               "Example:\n" +
               "  (length (generate-temporaries '(a b c))) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object lst = arguments[0];
        Object result = Value.NIL;
        Pair tail = null;
        while (lst != Value.NIL && Value.isPair(lst)) {
            String name = "tmp-" + counter.getAndIncrement();
            // Create as a SyntaxObject with a unique scope (fresh identifier)
            int scope = ScopeSet.freshScope();
            Object id = new SyntaxObject(name, ScopeSet.of(scope), pos);
            Pair cell = new Pair(id, Value.NIL);
            if (tail == null) { result = cell; tail = cell; }
            else { tail.cdr = cell; tail = cell; }
            lst = Value.asPair(lst).cdr;
        }
        return result;
    }
}
