package scheme.primitives;

import scheme.*;

public class PrimitiveInstructionOpcode extends Primitive {
    @Override
    public String name() {
        return "instruction-opcode";
    }

    @Override
    public String info() {
        return "Syntax: (instruction-opcode inst)\n" +
               "Library: (scm compile)\n" +
               "Description: Returns the opcode of the given bytecode instruction as a symbol.\n" +
               "Example:\n" +
               "  (instruction-opcode (car (get-code (lambda () 42)))) => LOAD_CONST";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.intern(Value.asInstruction(arguments[0]).opcode.toString());
    }
}
