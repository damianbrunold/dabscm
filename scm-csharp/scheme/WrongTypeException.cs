namespace scheme;

/// <summary>
/// A cast failure that knows the offending value. It is an
/// InvalidCastException, so the VM and the primitive call sites still turn it
/// into "Failed in &lt;name&gt;: wrong argument type", now with the value as
/// irritant.
/// </summary>
public class WrongTypeException : InvalidCastException
{
    public readonly object Value;
    public readonly string Expected;

    public WrongTypeException(object value, string expected)
        : base("expected " + expected)
    {
        Value = value;
        Expected = expected;
    }

    // A boxed .NET number that is no Scheme number (Scheme integers are long),
    // typically a primitive that returned an int by mistake.
    public static bool IsHostValue(object v) =>
        v is int or short or byte or sbyte or uint or ushort or ulong or float or decimal;
}
