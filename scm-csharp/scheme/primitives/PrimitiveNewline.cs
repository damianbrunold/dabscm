namespace scheme;

public class PrimitiveNewline : Primitive
{
    private Modules modules;

    public PrimitiveNewline(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "newline";
    }

    public override string Info()
    {
        return
            "Syntax: (newline) (newline port)\n" +
            "Library: (scheme write)\n" +
            "Description: Writes a newline character to the current output port or to the given port.\n" +
            "Example:\n" +
            "  (newline)\n" +
            "  (newline (open-output-string))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        TextWriter port;
        if (arguments.Length == 0)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
        }
        else
        {
            port = Value.AsOutputPort(arguments[0]);
        }
        try
        {
            port.Write("\n");
            port.Flush();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "newline: io failure: ~s", e.Message);
        }
    }
}
