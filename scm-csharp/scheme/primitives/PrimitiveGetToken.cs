using System.Globalization;

namespace scheme;

public class PrimitiveGetToken : Primitive
{
    private Modules modules;

    public PrimitiveGetToken(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "get-token";
    }

    public override string Info()
    {
        return
            "Syntax: (get-token) (get-token port)\n" +
            "Library: (scm core)\n" +
            "Description: Reads and returns the next token from the given input port (or current input port). Returns #f at end-of-input.\n" +
            "Example:\n" +
            "  (get-token (open-input-string \"(+ 1 2)\"))";
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
            var token = Tokenizer.ReadToken(port);
            if (token == null) return Value.F;
            return token.ToSexpr();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~s", e.Message);
        }
    }
}
