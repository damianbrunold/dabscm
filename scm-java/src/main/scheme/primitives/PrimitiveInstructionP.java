package scheme.primitives;

import scheme.*;

public class PrimitiveInstructionP extends Primitive {
    @Override
    public String name() {
        return "instruction?";
    }

    @Override
    public String info() {
        return "Syntax: (instruction? obj)\n" +
               "Library: (scm compile)\n" +
               "Description: Returns #t if obj is a bytecode instruction object, otherwise returns #f.\n" +
               "Example:\n" +
               "  (instruction? (car (get-code (lambda () 42)))) => #t";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isInstruction(arguments[0]);
    }
}
