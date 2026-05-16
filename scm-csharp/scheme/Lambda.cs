namespace scheme;

public class Lambda
{
    public string? name;
    public string? doc;
    public object env;
    public List<Instruction> code;

    public Lambda(object env, List<Instruction> code)
    {
        this.env = env;
        this.code = code;
    }

    public override string ToString()
    {
        return "#<" + (name == null ? "lambda" : name) + ">";
    }
}
