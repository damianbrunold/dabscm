namespace scheme;

public class Lambda
{
    public string? name;
    public string? doc;
    public object env;
    public List<Instruction> code;
    // code as an array, for the VM's dispatch loop
    public Instruction[] codeArr;

    public Lambda(object env, List<Instruction> code)
    {
        this.env = env;
        SetCode(code);
    }

    [System.Diagnostics.CodeAnalysis.MemberNotNull(nameof(code), nameof(codeArr))]
    public void SetCode(List<Instruction> code)
    {
        this.code = code;
        this.codeArr = code is CodeList cl ? cl.Array() : code.ToArray();
    }

    public override string ToString()
    {
        return "#<" + (name == null ? "lambda" : name) + ">";
    }
}
