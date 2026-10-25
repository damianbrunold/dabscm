namespace scheme;

public sealed class Lambda
{
    public string? name;
    public string? doc;
    public object env;
    public List<Instruction> code;
    // code as a CodeList (code itself, or a copy of another list)
    public CodeList cl;
    // code as an array, for the VM's dispatch loop
    public Instruction[] codeArr;

    public Lambda(object env, List<Instruction> code)
    {
        this.env = env;
        SetCode(code);
    }

    [System.Diagnostics.CodeAnalysis.MemberNotNull(nameof(code), nameof(cl), nameof(codeArr))]
    public void SetCode(List<Instruction> code)
    {
        this.code = code;
        if (code is CodeList list)
        {
            cl = list;
        }
        else
        {
            cl = new CodeList();
            cl.AddRange(code);
        }
        this.codeArr = cl.Array();
    }

    public override string ToString()
    {
        return "#<" + (name == null ? "lambda" : name) + ">";
    }
}
