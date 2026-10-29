package scheme.primitives;

import scheme.*;

public class PrimitiveImageDecodeRgba extends Primitive {
    @Override
    public String name() { return "image-decode-rgba"; }

    @Override
    public String info() {
        return "Syntax: (image-decode-rgba bytevector max-pixels)\n" +
               "Library: (scm image)\n" +
               "Description: Decodes a PNG or JPEG image to (width height pixels), pixels\n" +
               "  a bytevector of straight RGBA, 4 bytes per pixel, rows top to bottom.\n" +
               "  Signals an error for malformed or unsupported data and for images of\n" +
               "  more than max-pixels pixels (checked before decoding). Used by\n" +
               "  image-decode.";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        byte[] data = Value.asBytevector(arguments[0]);
        long max = (long) arguments[1];
        try {
            ImageCodec.Image img = ImageCodec.decode(data, max);
            return new Pair((long) img.width, new Pair((long) img.height, new Pair(img.rgba, Value.NIL)));
        } catch (ImageCodec.ImageException e) {
            throw new SchemeError(pos, "image-decode: ~a", e.getMessage());
        } catch (ArrayIndexOutOfBoundsException e) {
            throw new SchemeError(pos, "image-decode: ~a", "truncated or malformed image");
        }
    }
}
