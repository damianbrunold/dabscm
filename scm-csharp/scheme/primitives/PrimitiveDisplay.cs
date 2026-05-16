namespace scheme;

public class PrimitiveDisplay : Primitive
{
    private Modules modules;

    public PrimitiveDisplay(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "display";
    }

    public override string Info()
    {
        return
            "Syntax: (display obj) (display obj port)\n" +
            "Library: (scheme write)\n" +
            "Description: Writes a human-readable representation of obj to the current output port or the given port. Strings are written without quotes; characters are written without the #\\ prefix.\n" +
            "Example:\n" +
            "  (display \"hello\") => hello\n" +
            "  (display #\\a) => a";
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
            Value.DisplayRepTo(arguments[0], port);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
