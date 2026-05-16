namespace scheme;

public class PrimitiveWriteShared : Primitive
{
    private Modules modules;

    public PrimitiveWriteShared(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "write-shared";
    }

    public override string Info()
    {
        return
            "Syntax: (write-shared obj port?)\n" +
            "Library: (scheme write)\n" +
            "Description: Writes obj to the given port using datum labels (#N= and #N#) to represent all shared and cyclic structure.\n" +
            "Example:\n" +
            "  (let ((x (list 1 2))) (write-shared x)) => (1 2)\n" +
            "  (write-shared '#0=(a . #0#)) => #0=(a . #0#)";
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
            Value.PrintRepSharedTo(arguments[0], port);
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": failure due to: ~s", e.Message);
        }
    }
}
