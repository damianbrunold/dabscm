namespace scheme;

public class PrimitiveImageDecodeRgba : Primitive
{
    public override string Name() => "image-decode-rgba";

    public override string Info() =>
        "Syntax: (image-decode-rgba bytevector max-pixels)\n" +
        "Library: (scm image)\n" +
        "Description: Decodes a PNG or JPEG image to (width height pixels), pixels\n" +
        "  a bytevector of straight RGBA, 4 bytes per pixel, rows top to bottom.\n" +
        "  Signals an error for malformed or unsupported data and for images of\n" +
        "  more than max-pixels pixels (checked before decoding). Used by\n" +
        "  image-decode.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] data = Value.AsBytevector(arguments[0]);
        long max = (long)arguments[1];
        try
        {
            var img = ImageCodec.Decode(data, max);
            return new Pair((long)img.width, new Pair((long)img.height, new Pair(img.rgba, Value.NIL)));
        }
        catch (ImageCodec.ImageException e)
        {
            throw new SchemeError(pos, "image-decode: ~a", e.Message);
        }
        catch (IndexOutOfRangeException)
        {
            throw new SchemeError(pos, "image-decode: ~a", "truncated or malformed image");
        }
    }
}
