namespace scheme;

public class PrimitiveFlushOutputPort : Primitive
{
    private Modules modules;

    public PrimitiveFlushOutputPort(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "flush-output-port";
    }

    public override string Info()
    {
        return
            "Syntax: (flush-output-port) (flush-output-port port)\n" +
            "Library: (scheme base)\n" +
            "Description: Flushes any buffered output in the given output port (or current output port if omitted).\n" +
            "Example:\n" +
            "  (flush-output-port)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        object portObj;
        if (arguments.Length == 0)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            portObj = scmcore.Resolve(pos, "*output-port*");
        }
        else
        {
            portObj = arguments[0];
        }
        try
        {
            if (Value.IsBinaryOutputPort(portObj))
            {
                // Binary output ports have no flush; treat as no-op
                return new Values();
            }
            TextWriter port = Value.AsOutputPort(portObj);
            port.Flush();
            return new Values();
        }
        catch (ObjectDisposedException)
        {
            // Port already closed; flush is a no-op
            return new Values();
        }
        catch (Exception)
        {
            throw new SchemeError(pos, Name() + ": io failure");
        }
    }
}
