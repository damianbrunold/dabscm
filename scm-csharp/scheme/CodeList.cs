namespace scheme;

// The instruction list of compiled code. Caches its array form, which
// every Lambda over this code shares (a closure is created per FN).
public class CodeList : List<Instruction>
{
    private Instruction[]? array;

    public Instruction[] Array()
    {
        var a = array;
        if (a == null || a.Length != Count)
        {
            a = ToArray();
            array = a;
        }
        return a;
    }
}
