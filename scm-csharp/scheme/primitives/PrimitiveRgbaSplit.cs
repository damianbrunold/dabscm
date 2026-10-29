namespace scheme;

public class PrimitiveRgbaSplit : Primitive
{
    public override string Name() => "rgba-split";

    public override string Info() =>
        "Syntax: (rgba-split pixels components)\n" +
        "Library: (scm pdf)\n" +
        "Description: Splits straight RGBA pixels (a bytevector, 4 bytes per\n" +
        "  pixel) into (color alpha): color has components 3 (RGB) or 1 (gray,\n" +
        "  taken from the red byte) bytes per pixel, alpha 1; alpha is #f when\n" +
        "  every pixel is opaque. Used by pdf-embed-png.";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        byte[] px = Value.AsBytevector(arguments[0]);
        long comps = (long)arguments[1];
        if (comps != 1 && comps != 3)
            throw new SchemeError(pos, "rgba-split: components must be 1 or 3, got ~a", comps);
        if (px.Length % 4 != 0)
            throw new SchemeError(pos, "rgba-split: ~a", "pixel bytes not a multiple of 4");
        int n = px.Length / 4;
        int c = (int)comps;
        byte[] color = new byte[n * c];
        byte[] alpha = new byte[n];
        bool opaque = true;
        for (int i = 0, s = 0; i < n; i++, s += 4)
        {
            if (c == 3)
            {
                color[i * 3] = px[s];
                color[i * 3 + 1] = px[s + 1];
                color[i * 3 + 2] = px[s + 2];
            }
            else
            {
                color[i] = px[s];
            }
            byte a = px[s + 3];
            alpha[i] = a;
            if (a != 255) opaque = false;
        }
        return new Pair(color, new Pair(opaque ? (object)false : alpha, Value.NIL));
    }
}
