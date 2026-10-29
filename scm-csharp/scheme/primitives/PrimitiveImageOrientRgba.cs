namespace scheme;

public class PrimitiveImageOrientRgba : Primitive
{
    public override string Name() => "image-orient-rgba";

    public override string Info() =>
        "Syntax: (image-orient-rgba pixels width height orientation)\n" +
        "Library: (scm image)\n" +
        "Description: Applies EXIF orientation 1 to 8 to straight RGBA pixels and\n" +
        "  returns the new pixels (height x width for 5 to 8). Used by\n" +
        "  image-orient.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        byte[] px = Value.AsBytevector(arguments[0]);
        int w = (int)(long)arguments[1], h = (int)(long)arguments[2];
        int o = (int)(long)arguments[3];
        if (px.Length < (long)w * h * 4) throw new SchemeError(pos, "image-orient: ~a", "too few pixels");
        try
        {
            return ImageCodec.Orient(px, w, h, o);
        }
        catch (ImageCodec.ImageException e)
        {
            throw new SchemeError(pos, "image-orient: ~a", e.Message);
        }
    }
}
