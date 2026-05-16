namespace scheme;

public class PrimitiveInstructionP : Primitive
{
    public override string Name()
    {
        return "instruction?";
    }

    public override string Info()
    {
        return
            "Syntax: (instruction? obj)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns #t if obj is a bytecode instruction object, otherwise returns #f.\n" +
            "Example:\n" +
            "  (instruction? (car (get-code (lambda () 42)))) => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsInstruction(arguments[0]);
    }
}
