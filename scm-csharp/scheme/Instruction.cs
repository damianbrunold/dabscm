using System.Text;

namespace scheme;

public class Instruction
{
    public Opcode opcode;
    public object? arg1;
    public object? arg2;
    public SourcePos? pos;
    // Cached binding cell for GVAR/GSET fast path. Populated on first
    // successful resolution. Once set, the cell reference is stable for
    // ordinary use: Module.Bind reuses the existing cell when rebinding
    // an already-bound symbol. Bulk replacements via RestoreFromSnapshot
    // / ResetModules invalidate the cache via Modules.CacheGeneration.
    public Cell? cachedCell;
    public int cachedCellGeneration;

    public Instruction(Opcode opcode)
    {
        this.opcode = opcode;
    }

    public Instruction(Opcode opcode, object arg1)
    {
        this.opcode = opcode;
        this.arg1 = arg1;
    }

    public Instruction(Opcode opcode, object arg1, object arg2)
    {
        this.opcode = opcode;
        this.arg1 = arg1;
        this.arg2 = arg2;
    }

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
