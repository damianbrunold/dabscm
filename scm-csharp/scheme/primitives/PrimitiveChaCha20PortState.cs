namespace scheme;

public class PrimitiveChaCha20PortState : Primitive
{
    public override string Name() => "chacha20-port-state";
    public override string Info() =>
        "Syntax: (chacha20-port-state port)\n" +
        "Library: (srfi 271 determinized)\n" +
        "Description: Returns the position of the ChaCha20 port as a vector\n" +
        "  #(key counter offset): the next byte read is byte offset of keystream\n" +
        "  block counter. A byte taken by peek-u8 counts as not yet read.\n" +
        "Example:\n" +
        "  (chacha20-port-state (make-chacha20-port (make-bytevector 32 0) 0 5))\n" +
        "    => #(#u8(0 ...) 0 5)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (arguments[0] is not BinaryInputStream port || port.Source is not ChaCha20InputStream stream)
            throw new SchemeError(pos, "chacha20-port-state: not a ChaCha20 port");
        long counter = stream.Counter;
        long offset = stream.Offset;
        if (port.HasPeekedByte)
        {
            if (offset == 0)
            {
                counter--;
                offset = 63;
            }
            else
            {
                offset--;
            }
        }
        return new object[] { stream.Key, counter, offset };
    }
}
