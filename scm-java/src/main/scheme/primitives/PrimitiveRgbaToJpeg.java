package scheme.primitives;

import scheme.*;

public class PrimitiveRgbaToJpeg extends Primitive {
    @Override
    public String name() { return "rgba->jpeg"; }

    @Override
    public String info() {
        return "Syntax: (rgba->jpeg pixels width height quality)\n" +
               "Library: (scm image)\n" +
               "Description: Encodes straight RGBA pixels as a baseline JPEG (YCbCr 4:2:0,\n" +
               "  the standard tables scaled to quality 1 to 100), alpha composited over\n" +
               "  white. Returns the JPEG as a bytevector. Used by image->jpeg.";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        byte[] px = Value.asBytevector(arguments[0]);
        int w = (int) (long) arguments[1], h = (int) (long) arguments[2];
        int q = (int) (long) arguments[3];
        if (px.length < (long) w * h * 4) throw new SchemeError(pos, "image->jpeg: ~a", "too few pixels");
        try {
            return ImageCodec.encodeJpeg(px, w, h, q);
        } catch (ImageCodec.ImageException e) {
            throw new SchemeError(pos, "image->jpeg: ~a", e.getMessage());
        }
    }
}
