package scheme.primitives;

import scheme.*;

import java.io.Writer;

// (doc obj) — prints documentation for a procedure or macro to the current output port.
// (procedure-doc obj) — returns the doc string as a Scheme string (char[]), or #f if none.

public class PrimitiveDoc extends Primitive {
    private Modules modules;

    public PrimitiveDoc(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() { return "doc"; }

    @Override
    public String info() {
        return "Syntax: (doc obj)\n" +
               "Library: (scm core)\n" +
               "Description: Prints documentation for obj to the current output port. obj may be\n" +
               "  a procedure, primitive, macro, or symbol naming one. Returns unspecified.\n" +
               "Example:\n" +
               "  (doc car) => prints documentation for car";
    }

    private String getDoc(SourcePos pos, Object obj) {
        // Unwrap symbol
        if (Value.isSymbol(obj)) {
            String sym = Value.asSymbol(obj);
            if (modules.getCurrentModule().isBound(sym))
                obj = modules.getCurrentModule().resolve(sym);
            else
                return "(no documentation available)";
        }

        // Core form marker
        if (obj instanceof CoreFormMarker) {
            CoreFormMarker cfm = (CoreFormMarker) obj;
            return cfm.docstring != null ? cfm.docstring : "(no documentation available)";
        }

        // Unwrap macro transformer
        if (obj instanceof MacroTransformer) {
            MacroTransformer mt = (MacroTransformer) obj;
            if (mt.docstring != null) return mt.docstring;
            obj = mt.transformer;
        }

        if (Value.isLambda(obj)) {
            Lambda lam = Value.asLambda(obj);
            return lam.doc != null ? lam.doc : "(no documentation available)";
        }

        if (Value.isPrimitive(obj)) {
            return Value.asPrimitive(obj).info();
        }

        return "(no documentation available)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String doc = getDoc(pos, arguments[0]);
        Writer port = Value.asOutputPort(
            modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*"));
        try {
            port.write(doc);
            port.write("\n");
            port.flush();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
        return new Values();
    }
}
