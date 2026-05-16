namespace scheme;

public class PrimitiveWriteChar : Primitive
{
    private Modules modules;

    public PrimitiveWriteChar(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "write-char";
    }

    public override string Info()
    {
        return
            "Syntax: (write-char char port?)\n" +
            "Library: (scheme base)\n" +
            "Description: Writes the character char to the given textual output port, or to the current output port if no port is specified.\n" +
            "Example:\n" +
            "  (write-char #\\A) => (outputs A)\n" +
            "  (write-char #\\newline port)";
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
            port.Write(Value.AsChar(arguments[0]));
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "write-char: io failure: ~s", e.Message);
        }
    }
}
