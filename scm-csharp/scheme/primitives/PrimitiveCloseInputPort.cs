namespace scheme;

public class PrimitiveCloseInputPort : Primitive
{
    public override string Name()
    {
        return "close-input-port";
    }

    public override string Info()
    {
        return
            "Syntax: (close-input-port port)\n" +
            "Library: (scheme base)\n" +
            "Description: Closes the input port, releasing any resources. It is an error to read from a closed port.\n" +
            "Example:\n" +
            "  (let ((p (open-input-file \"data.txt\")))\n" +
            "    (close-input-port p))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            if (Value.IsBinaryInputPort(arguments[0]))
                Value.AsBinaryInputPort(arguments[0]).Close();
            else
                Value.AsInputPort(arguments[0]).Close();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "close-input-port: io failure: ~s", e.Message);
        }
    }
}
