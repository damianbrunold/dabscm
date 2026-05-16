namespace scheme;

// (doc obj) — prints documentation for a procedure or macro to the current output port.
// (procedure-doc obj) — returns the doc string as a Scheme string, or #f if none.

public class PrimitiveDoc : Primitive
{
    private Modules modules;

    public PrimitiveDoc(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "doc";

    public override string Info() =>
        "Syntax: (doc obj)\n" +
        "Library: (scm core)\n" +
        "Description: Prints documentation for obj to the current output port. obj may be\n" +
        "  a procedure, primitive, macro, or symbol naming one. Returns unspecified.\n" +
        "Example:\n" +
        "  (doc car) => prints documentation for car";

    private string GetDoc(SourcePos? pos, object obj)
    {
        // Unwrap symbol
        if (Value.IsSymbol(obj))
        {
            string sym = Value.AsSymbol(obj);
            if (modules.GetCurrentModule().IsBound(sym))
                obj = modules.GetCurrentModule().Resolve(pos, sym);
            else
                return "(no documentation available)";
        }

        // Core form marker
        if (obj is CoreFormMarker cfm)
            return cfm.Docstring ?? "(no documentation available)";

        // Unwrap macro transformer
        if (obj is MacroTransformer mt)
        {
            if (mt.Docstring != null) return mt.Docstring;
            obj = mt.Transformer;
        }

        if (Value.IsLambda(obj))
        {
            Lambda lam = Value.AsLambda(obj);
            return lam.doc ?? "(no documentation available)";
        }

        if (Value.IsPrimitive(obj))
        {
            return Value.AsPrimitive(obj).Info();
        }

        return "(no documentation available)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string doc = GetDoc(pos, arguments[0]);
        var scmcore = modules.GetModuleRequired(pos, "scm core");
        TextWriter port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
        port.Write(doc);
        port.Write("\n");
        port.Flush();
        return new Values();
    }
}

public class PrimitiveProcedureDoc : Primitive
{
    private Modules modules;

    public PrimitiveProcedureDoc(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "procedure-doc";

    public override string Info() =>
        "Syntax: (procedure-doc obj)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the documentation string for obj as a Scheme string, or #f\n" +
        "  if no documentation is available. obj may be a procedure, primitive, macro,\n" +
        "  or symbol naming one.\n" +
        "Example:\n" +
        "  (string? (procedure-doc car)) => #t";

    private object GetDocOrFalse(SourcePos? pos, object obj)
    {
        // Unwrap symbol
        if (Value.IsSymbol(obj))
        {
            string sym = Value.AsSymbol(obj);
            if (modules.GetCurrentModule().IsBound(sym))
                obj = modules.GetCurrentModule().Resolve(pos, sym);
            else
                return Value.F;
        }

        // Core form marker
        if (obj is CoreFormMarker cfm)
            return cfm.Docstring != null ? (object) cfm.Docstring.ToCharArray() : Value.F;

        // Unwrap macro transformer
        if (obj is MacroTransformer mt)
        {
            if (mt.Docstring != null) return mt.Docstring.ToCharArray();
            obj = mt.Transformer;
        }

        if (Value.IsLambda(obj))
        {
            Lambda lam = Value.AsLambda(obj);
            return lam.doc != null ? (object) lam.doc.ToCharArray() : Value.F;
        }

        if (Value.IsPrimitive(obj))
        {
            return Value.AsPrimitive(obj).Info().ToCharArray();
        }

        return Value.F;
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return GetDocOrFalse(pos, arguments[0]);
    }
}
