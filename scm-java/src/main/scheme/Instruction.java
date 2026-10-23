package scheme;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Instruction {

    public Opcode opcode;
    public Object arg1;
    public Object arg2;
    // third operand of the fused opcodes (see hasArg3)
    public Object arg3;
    // arg1/arg2/arg3 as ints when they are Integers (frame/var indexes,
    // jump targets, arg counts): read by the VM without unboxing
    public int i1;
    public int i2;
    public int i3;
    public SourcePos pos;
    // Cached binding cell for GVAR/GSET fast path. Populated on first
    // successful resolution. Once set, the cell reference is stable for
    // ordinary use: Module.bind reuses the existing cell when rebinding
    // an already-bound symbol. Bulk replacements via restoreFromSnapshot
    // / resetModules invalidate the cache via Modules.cacheGeneration.
    public Cell cachedCell;
    public int cachedCellGeneration;

    public Instruction() {}

    public Instruction(Opcode opcode) {
        this.opcode = opcode;
    }

    public Instruction(Opcode opcode, Object arg1) {
        this.opcode = opcode;
        this.arg1 = arg1;
        decodeInts();
    }

    public Instruction(Opcode opcode, Object arg1, Object arg2) {
        this.opcode = opcode;
        this.arg1 = arg1;
        this.arg2 = arg2;
        decodeInts();
    }

    public void decodeInts() {
        if (arg1 instanceof Integer) i1 = (Integer) arg1;
        if (arg2 instanceof Integer) i2 = (Integer) arg2;
        if (arg3 instanceof Integer) i3 = (Integer) arg3;
    }

    public static boolean hasArg3(Opcode opcode) {
        switch (opcode) {
            case GCALLS: case GCALLJ: case LVAR_VREF:
            case LVAR_NULL_FJUMP: case LVAR_PAIR_FJUMP:
                return true;
            default:
                return false;
        }
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
            if (arg3 != null) {
                result.append(" ").append(arg3);
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
