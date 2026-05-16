using System.Threading;

namespace scheme;

/// <summary>
/// A resolved binding describes what an identifier refers to.
/// </summary>
public class ResolvedBinding
{
    public enum Kind { Local, Global, Macro, PatternVar, CoreForm }

    public readonly Kind BindingKind;
    public readonly string Label;         // Unique label for identity comparison
    public readonly string? ModuleName;    // For Global/Macro: which module
    public readonly string SymbolName;    // The resolved symbol name in that module
    public readonly string ResolvedName;  // The name to use after stripping (may include module prefix)
    public readonly object? Value;         // For Macro: the transformer; for Local: SyntaxObject binding var

    private static int labelCounter = 0;

    public ResolvedBinding(Kind kind, string? moduleName, string symbolName, object? value = null)
    {
        this.BindingKind = kind;
        this.Label = "L" + Interlocked.Increment(ref labelCounter);
        this.ModuleName = moduleName;
        this.SymbolName = symbolName;
        this.ResolvedName = symbolName;
        this.Value = value;
    }

    public ResolvedBinding(Kind kind, string label, string? moduleName, string symbolName, string? resolvedName, object? value)
    {
        this.BindingKind = kind;
        this.Label = label;
        this.ModuleName = moduleName;
        this.SymbolName = symbolName;
        this.ResolvedName = resolvedName ?? symbolName;
        this.Value = value;
    }

    /// <summary>Create a macro binding.</summary>
    public static ResolvedBinding MakeMacro(string moduleName, string symbolName, object transformer)
    {
        return new ResolvedBinding(Kind.Macro, moduleName, symbolName, transformer);
    }

    /// <summary>Create a global variable binding.</summary>
    public static ResolvedBinding MakeGlobal(string moduleName, string symbolName)
    {
        return new ResolvedBinding(Kind.Global, moduleName, symbolName);
    }

    /// <summary>
    /// Create a local variable reference binding.
    /// The Value stores the binding variable's SyntaxObject (after scope is applied),
    /// which the Compiler uses to find the variable's position in the env.
    /// </summary>
    public static ResolvedBinding MakeLocalRef(string symbolName, SyntaxObject bindingVar)
    {
        return new ResolvedBinding(Kind.Local, null, symbolName, bindingVar);
    }

    /// <summary>Create a pattern variable binding (for syntax-rules).</summary>
    public static ResolvedBinding MakePatternVar(string symbolName, int depth, object value)
    {
        return new ResolvedBinding(Kind.PatternVar, null, symbolName, value);
    }

    /// <summary>Create a core form binding (if, lambda, let, etc.).</summary>
    public static ResolvedBinding MakeCoreForm(string formName)
    {
        return new ResolvedBinding(Kind.CoreForm, null, formName);
    }
}
