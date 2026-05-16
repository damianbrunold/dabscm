namespace scheme;

public class PrimitiveInstructionArg2 : Primitive
{
    public override string Name()
    {
        return "instruction-arg2";
    }

    public override string Info()
    {
        return
            "Syntax: (instruction-arg2 inst)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns the second argument of the given bytecode instruction, or unspecified if it has none.\n" +
            "Example:\n" +
            "  (instruction-arg2 (car (get-code (lambda () 42))))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Instruction instruction = Value.AsInstruction(arguments[0]);
        if (instruction.arg2 == null) return new Values();
        return instruction.arg2;
    }
}
