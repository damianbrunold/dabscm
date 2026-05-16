namespace scheme;

public class PrimitiveCloseOutputPort : Primitive
{
    public override string Name()
    {
        return "close-output-port";
    }

    public override string Info()
    {
        return
            "Syntax: (close-output-port port)\n" +
            "Library: (scheme base)\n" +
            "Description: Closes the output port, flushing any buffered output and releasing resources.\n" +
            "Example:\n" +
            "  (let ((p (open-output-file \"out.txt\")))\n" +
            "    (close-output-port p))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            if (Value.IsBinaryOutputPort(arguments[0]))
                Value.AsBinaryOutputPort(arguments[0]).Close();
            else
                Value.AsOutputPort(arguments[0]).Close();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "close-output-port: io failure: ~s", e.Message);
        }
    }
}
