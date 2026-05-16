package scheme.primitives;

import scheme.*;

public class PrimitiveProcedureDoc extends Primitive {
    private Modules modules;

    public PrimitiveProcedureDoc(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() { return "procedure-doc"; }

    @Override
    public String info() {
        return "Syntax: (procedure-doc obj)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the documentation string for obj as a Scheme string, or #f\n" +
               "  if no documentation is available. obj may be a procedure, primitive, macro,\n" +
               "  or symbol naming one.\n" +
               "Example:\n" +
               "  (string? (procedure-doc car)) => #t";
    }

    private Object getDocOrFalse(SourcePos pos, Object obj) {
        // Unwrap symbol
        if (Value.isSymbol(obj)) {
            String sym = Value.asSymbol(obj);
            if (modules.getCurrentModule().isBound(sym))
                obj = modules.getCurrentModule().resolve(sym);
            else
                return Value.F;
        }

        // Core form marker
        if (obj instanceof CoreFormMarker) {
            CoreFormMarker cfm = (CoreFormMarker) obj;
            return cfm.docstring != null ? cfm.docstring.toCharArray() : Value.F;
        }

        // Unwrap macro transformer
        if (obj instanceof MacroTransformer) {
            MacroTransformer mt = (MacroTransformer) obj;
            if (mt.docstring != null) return mt.docstring.toCharArray();
            obj = mt.transformer;
        }

        if (Value.isLambda(obj)) {
            Lambda lam = Value.asLambda(obj);
            return lam.doc != null ? lam.doc.toCharArray() : Value.F;
        }

        if (Value.isPrimitive(obj)) {
            return Value.asPrimitive(obj).info().toCharArray();
        }

        return Value.F;
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return getDocOrFalse(pos, arguments[0]);
    }
}
