namespace scheme;

public class PrimitiveReadData : Primitive
{
    public const int DefaultMaxDepth = 1000;

    private readonly PrimitiveRead reader;

    public PrimitiveReadData(Modules modules)
    {
        reader = new PrimitiveRead(modules);
    }

    public override string Name()
    {
        return "read-data";
    }

    public override string Info()
    {
        return
            "Syntax: (read-data port [max-depth])\n" +
            "Library: (scm io)\n" +
            "Description: Like read, for data from an untrusted source (uploads,\n" +
            "  pasted text, network). Datum labels (#0= and #0#) are rejected, so\n" +
            "  the result never shares structure or contains cycles, and lists,\n" +
            "  vectors and quote forms may nest at most max-depth levels (default\n" +
            "  1000). Either violation raises a read error (read-error? is true)\n" +
            "  instead of building a cyclic datum or exhausting the stack. Returns\n" +
            "  an end-of-file object at the end of the input.\n" +
            "Example:\n" +
            "  (read-data (open-input-string \"(a (b c))\")) => (a (b c))\n" +
            "  (read-data (open-input-string \"#0=(a . #0#)\")) => read error\n" +
            "  (read-data (open-input-string \"((x))\") 1) => read error";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        var port = Value.AsInputPort(arguments[0]);
        int maxDepth = DefaultMaxDepth;
        if (arguments.Length > 1)
        {
            long d = IntegerMath.ToLong(arguments[1]);
            if (d < 1) throw new SchemeError(pos, "read-data: max-depth must be positive");
            maxDepth = (int)Math.Min(d, 100000);
        }
        try
        {
            return reader.ReadData(port, maxDepth);
        }
        catch (SchemeError e)
        {
            if (e.errorObject != null) throw;
            throw new SchemeError(pos, new ReadErrorObject("read-data: " + e.Message, Array.Empty<object>()));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, new ReadErrorObject("read-data: " + e.Message, Array.Empty<object>()));
        }
    }
}
