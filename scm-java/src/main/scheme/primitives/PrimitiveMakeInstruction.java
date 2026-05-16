package scheme.primitives;

import scheme.*;

public class PrimitiveMakeInstruction extends Primitive {
    @Override
    public String name() {
        return "make-instruction";
    }

    @Override
    public String info() {
        return "Syntax: (make-instruction opcode) (make-instruction opcode arg1) (make-instruction opcode arg1 arg2)\n" +
               "Library: (scm compile)\n" +
               "Description: Creates a bytecode instruction object with the given opcode symbol and optional arguments.\n" +
               "Example:\n" +
               "  (make-instruction 'LOAD_CONST 42)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        Instruction instruction = new Instruction(Opcode.valueOf(Value.asSymbol(arguments[0])));
        if (arguments.length > 1) instruction.arg1 = arguments[1];
        if (arguments.length > 2) instruction.arg2 = arguments[2];
        return instruction;
    }
}
