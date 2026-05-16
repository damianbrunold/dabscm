package scheme;

import java.util.concurrent.atomic.AtomicInteger;

/**
 * A resolved binding describes what an identifier refers to.
 */
public class ResolvedBinding {
    public enum Kind { LOCAL, GLOBAL, MACRO, PATTERN_VAR, CORE_FORM }

    public final Kind bindingKind;
    public final String label;         // Unique label for identity comparison
    public final String moduleName;    // For Global/Macro: which module
    public final String symbolName;    // The resolved symbol name in that module
    public final String resolvedName;  // The name to use after stripping
    public final Object value;         // For Macro: the transformer; for Local: frame/index info

    private static final AtomicInteger labelCounter = new AtomicInteger(0);

    public ResolvedBinding(Kind kind, String moduleName, String symbolName, Object value) {
        this.bindingKind = kind;
        this.label = "L" + labelCounter.incrementAndGet();
        this.moduleName = moduleName;
        this.symbolName = symbolName;
        this.resolvedName = symbolName;
        this.value = value;
    }

    public ResolvedBinding(Kind kind, String moduleName, String symbolName) {
        this(kind, moduleName, symbolName, null);
    }

    public ResolvedBinding(Kind kind, String label, String moduleName, String symbolName, String resolvedName, Object value) {
        this.bindingKind = kind;
        this.label = label;
        this.moduleName = moduleName;
        this.symbolName = symbolName;
        this.resolvedName = resolvedName != null ? resolvedName : symbolName;
        this.value = value;
    }

    /** Create a macro binding. */
    public static ResolvedBinding makeMacro(String moduleName, String symbolName, Object transformer) {
        return new ResolvedBinding(Kind.MACRO, moduleName, symbolName, transformer);
    }

    /** Create a global variable binding. */
    public static ResolvedBinding makeGlobal(String moduleName, String symbolName) {
        return new ResolvedBinding(Kind.GLOBAL, moduleName, symbolName);
    }

    /** Create a local variable binding (lambda/let parameter). */
    public static ResolvedBinding makeLocal(String symbolName, int frame, int index) {
        return new ResolvedBinding(Kind.LOCAL, null, symbolName, new int[] { frame, index });
    }

    /**
     * Create a local variable reference binding for the Dybvig scope protocol.
     * The value stores the binding variable's SyntaxObject (after scope mark),
     * which the Compiler uses to find the variable's position in the env.
     */
    public static ResolvedBinding makeLocalRef(String symbolName, SyntaxObject bindingVar) {
        return new ResolvedBinding(Kind.LOCAL, null, symbolName, bindingVar);
    }

    /** Create a pattern variable binding (for syntax-rules/syntax-case). */
    public static ResolvedBinding makePatternVar(String symbolName, int depth, Object value) {
        return new ResolvedBinding(Kind.PATTERN_VAR, null, symbolName, value);
    }

    /** Create a core form binding (if, lambda, let, etc.). */
    public static ResolvedBinding makeCoreForm(String formName) {
        return new ResolvedBinding(Kind.CORE_FORM, null, formName);
    }
}
