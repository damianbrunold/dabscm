namespace scheme;

public class PrimitiveWriteSimple : Primitive
{
    private Modules modules;

    public PrimitiveWriteSimple(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "write-simple";
    }

    public override string Info()
    {
        return
            "Syntax: (write-simple obj port?)\n" +
            "Library: (scheme write)\n" +
            "Description: Writes obj to the given port without performing shared-structure detection, making it faster but unable to handle cyclic data.\n" +
            "Example:\n" +
            "  (write-simple '(1 2 3)) => (1 2 3)\n" +
            "  (write-simple \"hello\") => \"hello\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        TextWriter port;
        if (arguments.Length == 1)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
        }
        else
        {
            port = Value.AsOutputPort(arguments[1]);
        }
        try
        {
            Value.PrintRepTo(arguments[0], port);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": failure due to: ~s", e.Message);
        }
    }
}
