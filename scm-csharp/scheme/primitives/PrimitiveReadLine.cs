using System.Text;

namespace scheme;

public class PrimitiveReadLine : Primitive
{
    private Modules modules;

    public PrimitiveReadLine(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "read-line";
    }

    public override string Info()
    {
        return
            "Syntax: (read-line)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the next line of text available from the input port as a string, discarding the newline. If end of file is reached before any characters are read, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"hello\\nworld\"))\n" +
            "  (read-line p) => \"hello\"\n" +
            "  (read-line p) => \"world\"";
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
            var line = port.ReadLine();
            if (line == null) return Value.EOF;
            return line.ToCharArray();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "read-line: io failure: ~s", e.Message);
        }
    }
}
