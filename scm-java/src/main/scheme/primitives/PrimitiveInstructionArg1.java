package scheme.primitives;

import scheme.*;

public class PrimitiveInstructionArg1 extends Primitive {
    @Override
    public String name() {
        return "instruction-arg1";
    }

    @Override
    public String info() {
        return "Syntax: (instruction-arg1 inst)\n" +
               "Library: (scm compile)\n" +
               "Description: Returns the first argument of the given bytecode instruction, or unspecified if it has none.\n" +
               "Example:\n" +
               "  (instruction-arg1 (car (get-code (lambda () 42))))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Instruction instruction = Value.asInstruction(arguments[0]);
        if (instruction.arg1 == null) return new Values();
        return instruction.arg1;
    }
}
