namespace scheme;

public class Pair
{
    public object car;
    public object cdr;
    public SourcePos? pos;

    public Pair(object car, object cdr)
    {
        this.car = car;
        this.cdr = cdr;
        this.pos = null;
    }

    public Pair(object car, object cdr, SourcePos? pos)
    {
        this.car = car;
        this.cdr = cdr;
        this.pos = pos;
    }

    public Pair WithPos(SourcePos? pos)
    {
        this.pos = pos;
        return this;
    }
    
    public static object List(params object[]  values)
    {
        object result = Value.NIL;
        for (int i = values.Length - 1; i >= 0; i--)
        {
            result = new Pair(values[i], result);
        }
        return result;
    }

    public static Pair List2(object first, params object[] rest)
    {
        return new Pair(first, List(rest));
    }

    public static void AppendToList(object list, List<object> collect)
    {
        while (list != Value.NIL)
        {
            collect.Add(Value.AsPair(list).car);
            list = Value.AsPair(list).cdr;
        }
    }

    public int Length()
    {
        int result = 0;
        object p = this;
        while (p != Value.NIL)
        {
            result++;
            p = Value.AsPair(p).cdr;
        }
        return result;
    }

    public object NthCdr(int n)
    {
        object result = this;
        while (n > 0)
        {
            result = Value.AsPair(result).cdr;
            n--;
        }
        return result;
    }

    public object Nth(int n)
    {
        return Value.AsPair(NthCdr(n)).car;
    }

    public object First() { return car; }
    public object Second() { return Value.AsPair(cdr).car; }
    public object Third() { return Nth(2); }
    public object Fourth() { return Nth(3); }
    public object Fifth() { return Nth(4); }
    public object Sixth() { return Nth(5); }
    public object Seventh() { return Nth(6); }
    public object Eight() { return Nth(7); }
    public object Ninth() { return Nth(8); }
    public object Tenth() { return Nth(9); }

    public override string ToString()
    {
        return Value.PrintRep(this);
    }
}
