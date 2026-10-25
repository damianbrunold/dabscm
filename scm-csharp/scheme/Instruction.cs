using System.Text;

namespace scheme;

public sealed class Instruction
{
    public Opcode opcode;
    public object? arg1;
    public object? arg2;
    // third operand of the fused opcodes (see HasArg3)
    public object? arg3;
    // arg1/arg2/arg3 as ints when they are ints (frame/var indexes, jump
    // targets, arg counts): read by the VM without unboxing
    public int i1;
    public int i2;
    public int i3;
    public SourcePos? pos;
    // Cached binding cell for GVAR/GSET fast path. Populated on first
    // successful resolution. Once set, the cell reference is stable for
    // ordinary use: Module.Bind reuses the existing cell when rebinding
    // an already-bound symbol. Bulk replacements via RestoreFromSnapshot
    // / ResetModules invalidate the cache via Modules.CacheGeneration.
    public Cell? cachedCell;
    public int cachedCellGeneration;
    // the same for compiled code, against Modules.Generation (Rt)
    public Cell? jitCell;
    public int jitCellGeneration;

    public Instruction(Opcode opcode)
    {
        this.opcode = opcode;
    }

    public Instruction(Opcode opcode, object arg1)
    {
        this.opcode = opcode;
        this.arg1 = arg1;
        DecodeInts();
    }

    public Instruction(Opcode opcode, object arg1, object arg2)
    {
        this.opcode = opcode;
        this.arg1 = arg1;
        this.arg2 = arg2;
        DecodeInts();
    }

    public void DecodeInts()
    {
        if (arg1 is int a1) i1 = a1;
        if (arg2 is int a2) i2 = a2;
        if (arg3 is int a3) i3 = a3;
    }

    public static bool HasArg3(Opcode opcode) => opcode switch
    {
        Opcode.GCALLS or Opcode.GCALLJ or Opcode.LVAR_VREF
            or Opcode.LVAR_NULL_FJUMP or Opcode.LVAR_PAIR_FJUMP or Opcode.LOOP => true,
        _ => false
    };

    public Instruction WithPos(SourcePos? pos)
    {
        this.pos = pos;
        return this;
    }

    public override string ToString()
    {
        var result = new StringBuilder();
        result.Append(opcode);
        if (arg1 != null)
        {
            result.Append(" ").Append(Value.PrintRep(arg1));
            if (arg2 != null)
            {
                if (Value.IsSymbol(arg2))
                {
                    result.Append(" \"").Append(Value.PrintRep(arg2)).Append("\"");
                }
                else
                {
                    result.Append(" ").Append(Value.PrintRep(arg2));
                }
            }
            if (arg3 != null)
            {
                result.Append(" ").Append(Value.PrintRep(arg3));
            }
            if (pos != null)
            {
                result.Append(" ").Append(pos);
            }
        }
        return result.ToString();
    }

    public static List<Instruction> Seq(params Instruction[] instructions)
    {
        List<Instruction> result = new();
        foreach (var inst in instructions)
        {
            result.Add(inst);
        }
        return result;
    }
}
