namespace scheme;

public class PrimitiveWrite : Primitive
{
    private Modules modules;

    public PrimitiveWrite(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "write";
    }

    public override string Info()
    {
        return
            "Syntax: (write obj port?)\n" +
            "Library: (scheme write)\n" +
            "Description: Writes a machine-readable representation of obj to the given port, or the current output port. Strings are written with quotes and special characters escaped.\n" +
            "Example:\n" +
            "  (write '(1 \"two\" #\\3)) => (1 \"two\" #\\3)\n" +
            "  (write 'hello) => hello";
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
            Value.PrintRepCyclicTo(arguments[0], port);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": failure due to: ~s", e.Message);
        }
    }
}
