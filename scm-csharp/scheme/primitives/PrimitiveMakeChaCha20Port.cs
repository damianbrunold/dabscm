namespace scheme;

public class PrimitiveMakeChaCha20Port : Primitive
{
    public override string Name() => "make-chacha20-port";
    public override string Info() =>
        "Syntax: (make-chacha20-port key counter offset)\n" +
        "Library: (srfi 271 determinized)\n" +
        "Description: Returns a binary input port delivering the endless ChaCha20\n" +
        "  keystream for the 32-byte bytevector key (all-zero nonce), starting at\n" +
        "  byte offset (0..63) of block counter (0..2^63-1).\n" +
        "Example:\n" +
        "  (read-u8 (make-chacha20-port (make-bytevector 32 0) 0 0)) => 118";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        if (!Value.IsBytevector(arguments[0]) || Value.AsBytevector(arguments[0]).Length != 32)
            throw new SchemeError(pos, "make-chacha20-port: key must be a bytevector of length 32");
        if (!Value.IsFixnum(arguments[1]) || Value.AsInteger(arguments[1]) < 0)
            throw new SchemeError(pos, "make-chacha20-port: counter must be an exact integer in 0..2^63-1");
        if (!Value.IsFixnum(arguments[2])
            || Value.AsInteger(arguments[2]) < 0 || Value.AsInteger(arguments[2]) > 63)
            throw new SchemeError(pos, "make-chacha20-port: offset must be an exact integer in 0..63");
        var stream = new ChaCha20InputStream(Value.AsBytevector(arguments[0]),
                                             Value.AsInteger(arguments[1]),
                                             (int)Value.AsInteger(arguments[2]));
        return new BinaryInputStream(stream, false);
    }
}
