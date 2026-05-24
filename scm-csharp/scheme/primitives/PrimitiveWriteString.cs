namespace scheme;

public class PrimitiveWriteString : Primitive
{
    private Modules modules;

    public PrimitiveWriteString(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "write-string";

    public override string Info() =>
        "Syntax: (write-string string)\n" +
        "       (write-string string port)\n" +
        "       (write-string string port start)\n" +
        "       (write-string string port start end)\n" +
        "Library: (scheme base)\n" +
        "Description: Writes the characters of string from start to end " +
        "in left-to-right order to the given port. port defaults to the " +
        "current output port. start defaults to 0 and end defaults to the " +
        "length of string. The native primitive does a single bulk write " +
        "via TextWriter.Write(char[], start, count) — large strings " +
        "(catalog_text payloads, large s-exp blobs) don't pay the " +
        "Scheme→native transition per char.\n" +
        "Example:\n" +
        "  (write-string \"hello\")\n" +
        "  (write-string \"hello\" port 1 3)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 4);
        char[] s = Value.AsString(arguments[0]);
        TextWriter port;
        if (arguments.Length >= 2)
        {
            port = Value.AsOutputPort(arguments[1]);
        }
        else
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
        }
        int start = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : 0;
        int end   = arguments.Length >= 4 ? IntegerMath.ToInt(arguments[3]) : s.Length;
        try
        {
            port.Write(s, start, end - start);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "write-string: io failure: ~s", e.Message);
        }
    }
}
