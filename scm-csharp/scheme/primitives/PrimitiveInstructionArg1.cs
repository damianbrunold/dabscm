namespace scheme;

public class PrimitiveInstructionArg1 : Primitive
{
    public override string Name()
    {
        return "instruction-arg1";
    }

    public override string Info()
    {
        return
            "Syntax: (instruction-arg1 inst)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns the first argument of the given bytecode instruction, or unspecified if it has none.\n" +
            "Example:\n" +
            "  (instruction-arg1 (car (get-code (lambda () 42))))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Instruction instruction = Value.AsInstruction(arguments[0]);
        if (instruction.arg1 == null) return new Values();
        return instruction.arg1;
    }
}
