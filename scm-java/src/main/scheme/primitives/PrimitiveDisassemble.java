package scheme.primitives;

import scheme.*;

import java.io.Writer;
import java.util.List;

public class PrimitiveDisassemble extends Primitive {
    private Modules modules;

    public PrimitiveDisassemble(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "disassemble";
    }

    @Override
    public String info() {
        return "Syntax: (disassemble fn) (disassemble fn port)\n" +
               "Library: (scm compile)\n" +
               "Description: Writes a human-readable disassembly of the bytecode of the lambda fn to the current output port (or to port if given).\n" +
               "Example:\n" +
               "  (disassemble (lambda (x) (+ x 1)))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Lambda fn = Value.asLambda(arguments[0]);
        Writer port;
        if (arguments.length == 1) {
            port = Value.asOutputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*output-port*"));
        } else {
            port = Value.asOutputPort(arguments[1]);
        }
        try {
            port.write(fn.name + "\n");
            port.write("env: " + Value.printRep(fn.env) + "\n");
            writeCode(port, fn.code, "");
            port.flush();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "disassemble: i/o error");
        }
    }

    @SuppressWarnings("unchecked")
    private void writeCode(Writer port, List<Instruction> code, String indent) throws Exception {
        int index = 0;
        for (Instruction instruction : code) {
            if (instruction.opcode == Opcode.FN) {
                port.write(String.format("%s%-3s %s\n", indent, index + ":", instruction.opcode.toString()));
                port.write(indent + "    env: " + Value.asPair(instruction.arg1).second() + "\n");
                port.write(indent + "    args: " + Value.asPair(instruction.arg1).fourth() + "\n");
                writeCode(port, (List<Instruction>) Value.asPair(instruction.arg1).sixth(), indent + "    ");
            } else {
                port.write(String.format("%s%-3s %s\n", indent, index + ":", instruction.toString()));
            }
            index++;
        }
    }
}
