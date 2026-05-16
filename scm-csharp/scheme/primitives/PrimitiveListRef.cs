namespace scheme;

public class PrimitiveListRef : Primitive
{
    public override string Name()
    {
        return "list-ref";
    }

    public override string Info()
    {
        return
            "Syntax: (list-ref list k)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the k-th element (zero-indexed) of list. It is an error if k is out of range.\n" +
            "Example:\n" +
            "  (list-ref '(a b c) 0) => a\n" +
            "  (list-ref '(a b c) 2) => c";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        // (define (list-ref ls n)
        //   (if (= n 0)
        //       (car ls)
        //       (list-ref (cdr ls) (- n 1))))

        CheckArgs(pos, arguments, 2, 2);

        var head = Value.AsPair(arguments[0]);
        var n = IntegerMath.ToInt(arguments[1]);
        while (n > 0)
        {
            head = Value.AsPair(head.cdr);
            n--;
        }
        return head.car;
    }
}
