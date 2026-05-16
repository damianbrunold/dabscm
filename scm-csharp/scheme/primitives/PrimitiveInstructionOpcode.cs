namespace scheme;

public class PrimitiveInstructionOpcode : Primitive
{
    public override string Name()
    {
        return "instruction-opcode";
    }

    public override string Info()
    {
        return
            "Syntax: (instruction-opcode inst)\n" +
            "Library: (scm compile)\n" +
            "Description: Returns the opcode of the given bytecode instruction as a symbol.\n" +
            "Example:\n" +
            "  (instruction-opcode (car (get-code (lambda () 42)))) => LOAD_CONST";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.Intern(Value.AsInstruction(arguments[0]).opcode.ToString());
    }
}
