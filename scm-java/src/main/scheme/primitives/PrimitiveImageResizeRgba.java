package scheme.primitives;

import scheme.*;

public class PrimitiveImageResizeRgba extends Primitive {
    @Override
    public String name() { return "image-resize-rgba"; }

    @Override
    public String info() {
        return "Syntax: (image-resize-rgba pixels width height new-width new-height method)\n" +
               "Library: (scm image)\n" +
               "Description: Resizes straight RGBA pixels; method is 'box (area average)\n" +
               "  or 'bilinear. Returns the new pixels. Used by image-resize.";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 6, 6);
        byte[] px = Value.asBytevector(arguments[0]);
        int w = (int) (long) arguments[1], h = (int) (long) arguments[2];
        int nw = (int) (long) arguments[3], nh = (int) (long) arguments[4];
        String m = Value.asSymbol(arguments[5]);
        int method;
        if (m.equals("box")) method = 0;
        else if (m.equals("bilinear")) method = 1;
        else throw new SchemeError(pos, "image-resize: unknown method ~a (box or bilinear)", m);
        try {
            return ImageCodec.resize(px, w, h, nw, nh, method);
        } catch (ImageCodec.ImageException e) {
            throw new SchemeError(pos, "image-resize: ~a", e.getMessage());
        }
    }
}
