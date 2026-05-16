namespace scheme;

public class PrimitiveMakePolar : Primitive
{
    public override string Name()
    {
        return "make-polar";
    }

    public override string Info()
    {
        return
            "Syntax: (make-polar r theta)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the complex number r * e^(i*theta).\n" +
            "Example:\n" +
            "  (make-polar 1 0) => 1.0\n" +
            "  (make-polar 1 1) => 0.5403023058681398+0.8414709848078965i";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        double r = ToReal(arguments[0]);
        double theta = ToReal(arguments[1]);
        return Complex.Create(r * Math.Cos(theta), r * Math.Sin(theta));
    }
}
