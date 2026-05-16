namespace scheme;

public class NativeValue
{
    public object value;

    public NativeValue(object value)
    {
        this.value = value;
    }
    
    public override string ToString()
    {
        return value?.ToString() ?? "?";
    }
}
