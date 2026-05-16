namespace scheme;

public class PrimitiveGetEnvironmentVariables : Primitive
{
    public override string Name() => "get-environment-variables";

    public override string Info() =>
        "Syntax: (get-environment-variables)\n" +
        "Library: (scheme process-context)\n" +
        "Description: Returns an association list of all environment variables as (name . value) pairs, where both are strings.\n" +
        "Example:\n" +
        "  (assoc \"HOME\" (get-environment-variables)) => (\"HOME\" . \"/home/user\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var vars = System.Environment.GetEnvironmentVariables();
        object result = Value.NIL;
        foreach (System.Collections.DictionaryEntry entry in vars)
        {
            var key = entry.Key.ToString()!.ToCharArray();
            var val = (entry.Value?.ToString() ?? "").ToCharArray();
            result = new Pair(new Pair(key, val), result);
        }
        return result;
    }
}
