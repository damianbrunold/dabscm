namespace scheme;

public class PrimitiveGetEnvironmentVariable : Primitive
{
    public override string Name()
    {
        return "get-environment-variable";
    }

    public override string Info()
    {
        return
            "Syntax: (get-environment-variable name)\n" +
            "Library: (scm system) (scheme process-context) (srfi 98)\n" +
            "Description: Returns the value of the environment variable named name as a string, or #f if it is not set.\n" +
            "Example:\n" +
            "  (get-environment-variable \"HOME\") => \"/home/user\"\n" +
            "  (get-environment-variable \"UNDEFINED_VAR\") => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var name = new String(Value.AsString(arguments[0]));
        var value = Environment.GetEnvironmentVariable(name);
        if (value != null)
        {
            return value.ToCharArray();
        }
        else
        {
            return Value.F;
        }
    }
}
