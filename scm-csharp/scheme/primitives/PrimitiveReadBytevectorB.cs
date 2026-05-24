namespace scheme;

public class PrimitiveReadBytevectorB : Primitive
{
    public override string Name() => "read-bytevector!";
    public override string Info() =>
        "Syntax: (read-bytevector! bv port)\n" +
        "Library: (scheme base)\n" +
        "Description: Reads bytes from the binary input port into the bytevector bv, starting at start (default 0) and ending before end (default length of bv). Returns the number of bytes read, or an end-of-file object if no bytes were available.\n" +
        "Example:\n" +
        "  (let ((bv (make-bytevector 3 0))\n" +
        "        (p (open-input-bytevector #u8(1 2 3))))\n" +
        "    (read-bytevector! bv p)\n" +
        "    bv) => #u8(1 2 3)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 4);
        try
        {
            byte[] bv = Value.AsBytevector(arguments[0]);
            BinaryInputStream port = Value.AsBinaryInputPort(arguments[1]);
            int start = arguments.Length >= 3 ? IntegerMath.ToInt(arguments[2]) : 0;
            int end = arguments.Length >= 4 ? IntegerMath.ToInt(arguments[3]) : bv.Length;
            int count = end - start;
            int read = count > 0 ? port.Read(bv, start, count) : 0;
            return read == 0 ? (object)Value.EOF : (object)(long)read;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "read-bytevector!: io failure: ~a", e.Message);
        }
    }
}
