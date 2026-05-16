package scheme;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Instruction {

    public Opcode opcode;
    public Object arg1;
    public Object arg2;
    public SourcePos pos;

    public Instruction() {}

    public Instruction(Opcode opcode) {
        this.opcode = opcode;
    }

    public Instruction(Opcode opcode, Object arg1) {
        this.opcode = opcode;
        this.arg1 = arg1;
    }

    public Instruction(Opcode opcode, Object arg1, Object arg2) {
        this.opcode = opcode;
        this.arg1 = arg1;
        this.arg2 = arg2;
    }

    public Instruction withPos(SourcePos pos)
    {
        this.pos = pos;
        return this;
    }

    @Override
    public String toString() {
        StringBuilder result = new StringBuilder();
        result.append(opcode);
        if (arg1 != null) {
            result.append(" ").append(arg1);
            if (arg2 != null) {
                if (arg2 instanceof String) {
                    result.append(" \"").append(arg2).append("\"");
                } else {
                    result.append(" ").append(arg2);
                }
            }
            if (pos != null) {
                result.append(" ").append(pos);
            }
        }
        return result.toString();
    }

    public static List<Instruction> seq(Instruction... instruction) {
        List<Instruction> result = new ArrayList<>();
        Collections.addAll(result, instruction);
        return result;
    }

}
