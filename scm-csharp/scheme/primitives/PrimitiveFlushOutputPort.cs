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
                // Binary output ports now buffer (BinaryOutputStream
                // wraps non-MemoryStream sinks in BufferedStream so
                // byte-at-a-time wire-protocol writers don't pay a
                // syscall per byte). Flush so e.g. the postgres
                // request actually reaches the server before we wait
                // on the read.
                BinaryOutputStream bp = Value.AsBinaryOutputPort(portObj);
                bp.Flush();
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
