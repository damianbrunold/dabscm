namespace scheme;

public class PrimitiveReadChar : Primitive
{
    private Modules modules;

    public PrimitiveReadChar(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "read-char";
    }

    public override string Info()
    {
        return
            "Syntax: (read-char)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the next character available from the input port, updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"ab\"))\n" +
            "  (read-char p) => #\\a\n" +
            "  (read-char p) => #\\b";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        TextStream port;
        if (arguments.Length == 0)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsInputPort(scmcore.Resolve(pos, "*input-port*"));
        }
        else
        {
            port = Value.AsInputPort(arguments[0]);
        }
        try
        {
            int ch = port.Read();
            if (ch == -1) return Value.EOF;
            return (char) ch;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "read-char: io failure: ~s", e.Message);
        }
    }
}
