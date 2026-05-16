namespace scheme;

public class ReturnAddress
{
    public int ip;
    public Lambda fn;
    public object env;

    public ReturnAddress(int ip, Lambda fn, object env)
    {
        this.ip = ip;
        this.fn = fn;
        this.env = env;
    }

    public override string ToString()
    {
        return "#<RETADDR:" + ip + ">";
    }
}
