namespace scheme;

public class PrimitiveMakeRectangular : Primitive
{
    public override string Name()
    {
        return "make-rectangular";
    }

    public override string Info()
    {
        return
            "Syntax: (make-rectangular x y)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the complex number x + yi.\n" +
            "Example:\n" +
            "  (make-rectangular 1 2) => 1+2i\n" +
            "  (make-rectangular 3 0) => 3";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return Complex.Create(arguments[0], arguments[1]);
    }
}
