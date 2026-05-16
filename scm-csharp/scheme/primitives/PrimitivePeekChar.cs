namespace scheme;

public class PrimitivePeekChar : Primitive
{
    private Modules modules;

    public PrimitivePeekChar(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "peek-char";
    }

    public override string Info()
    {
        return
            "Syntax: (peek-char)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the next character available from the input port without updating the port to point past the character. If no more characters are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"ab\"))\n" +
            "  (peek-char p) => #\\a\n" +
            "  (read-char p) => #\\a";
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
            int ch = port.Peek();
            if (ch == -1) return Value.EOF;
            return (char) ch;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "peek-char: io failure: ~s", e.Message);
        }
    }
}
