namespace scheme;

public class PrimitivePrimitive : Primitive
{
    private Primitives primitives;

    public PrimitivePrimitive(Primitives primitives)
    {
        this.primitives = primitives;
    }

    public override string Name() => "%primitive";

    public override string Info() =>
        "Syntax: (%primitive symbol)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the built-in primitive procedure named by symbol. Used internally by library files to bind C# primitives.\n" +
        "Example:\n" +
        "  (%primitive 'car) => #<primitive car>\n" +
        "  (%primitive \"cons\") => #<primitive cons>";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string name = Value.IsSymbol(arguments[0])
            ? Value.AsSymbol(arguments[0])
            : new string(Value.AsString(arguments[0]));
        return primitives.GetPrimitive(pos, name);
    }
}
