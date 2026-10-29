namespace scheme;

public class PrimitiveImageResizeRgba : Primitive
{
    public override string Name() => "image-resize-rgba";

    public override string Info() =>
        "Syntax: (image-resize-rgba pixels width height new-width new-height method)\n" +
        "Library: (scm image)\n" +
        "Description: Resizes straight RGBA pixels; method is 'box (area average)\n" +
        "  or 'bilinear. Returns the new pixels. Used by image-resize.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 6, 6);
        byte[] px = Value.AsBytevector(arguments[0]);
        int w = (int)(long)arguments[1], h = (int)(long)arguments[2];
        int nw = (int)(long)arguments[3], nh = (int)(long)arguments[4];
        string m = Value.AsSymbol(arguments[5]);
        int method;
        if (m == "box") method = 0;
        else if (m == "bilinear") method = 1;
        else throw new SchemeError(pos, "image-resize: unknown method ~a (box or bilinear)", m);
        try
        {
            return ImageCodec.Resize(px, w, h, nw, nh, method);
        }
        catch (ImageCodec.ImageException e)
        {
            throw new SchemeError(pos, "image-resize: ~a", e.Message);
        }
    }
}
