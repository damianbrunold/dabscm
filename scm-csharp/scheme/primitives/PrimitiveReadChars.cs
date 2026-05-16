using System.Text;

namespace scheme;

public class PrimitiveReadChars : Primitive
{
    private Modules modules;

    public PrimitiveReadChars(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "read-chars";
    }

    public override string Info()
    {
        return
            "Syntax: (read-chars n port)\n" +
            "Library: (scm io)\n" +
            "Description: Reads up to n characters from the textual input port and returns them as a string. Returns an end-of-file object if no characters are available.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"hello\"))\n" +
            "  (read-chars 3 p) => \"hel\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        int size = IntegerMath.ToInt(arguments[0]);
        TextStream port;
        if (arguments.Length == 1)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsInputPort(scmcore.Resolve(pos, "*input-port*"));
        }
        else
        {
            port = Value.AsInputPort(arguments[1]);
        }
        try
        {
            int c = port.Read();
            if (c == -1) return Value.EOF;
            StringBuilder result = new StringBuilder();
            while (c != -1)
            {
                char ch = (char) c;
                result.Append(ch);
                if (result.Length == size)
                {
                    break;
                }
                c = port.Read();
            }
            return result.ToString().ToCharArray();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~s", e.Message);
        }
    }
}
