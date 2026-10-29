namespace scheme;

public class PrimitiveRgbaToJpeg : Primitive
{
    public override string Name() => "rgba->jpeg";

    public override string Info() =>
        "Syntax: (rgba->jpeg pixels width height quality)\n" +
        "Library: (scm image)\n" +
        "Description: Encodes straight RGBA pixels as a baseline JPEG (YCbCr 4:2:0,\n" +
        "  the standard tables scaled to quality 1 to 100), alpha composited over\n" +
        "  white. Returns the JPEG as a bytevector. Used by image->jpeg.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] px = Value.AsBytevector(arguments[0]);
        int w = (int)(long)arguments[1], h = (int)(long)arguments[2];
        int q = (int)(long)arguments[3];
        if (px.Length < (long)w * h * 4) throw new SchemeError(pos, "image->jpeg: ~a", "too few pixels");
        try
        {
            return ImageCodec.EncodeJpeg(px, w, h, q);
        }
        catch (ImageCodec.ImageException e)
        {
            throw new SchemeError(pos, "image->jpeg: ~a", e.Message);
        }
    }
}
