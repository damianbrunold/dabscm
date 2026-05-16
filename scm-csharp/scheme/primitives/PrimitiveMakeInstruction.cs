namespace scheme;

public class PrimitiveMakeInstruction : Primitive
{
    public override string Name()
    {
        return "make-instruction";
    }

    public override string Info()
    {
        return
            "Syntax: (make-instruction opcode) (make-instruction opcode arg1) (make-instruction opcode arg1 arg2)\n" +
            "Library: (scm compile)\n" +
            "Description: Creates a bytecode instruction object with the given opcode symbol and optional arguments.\n" +
            "Example:\n" +
            "  (make-instruction 'LOAD_CONST 42)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        Opcode opcode;
        Enum.TryParse(Value.AsSymbol(arguments[0]), out opcode);
        Instruction instruction = new Instruction(opcode);
        if (arguments.Length > 1) instruction.arg1 = arguments[1];
        if (arguments.Length > 2) instruction.arg2 = arguments[2];
        return instruction;
    }
}
