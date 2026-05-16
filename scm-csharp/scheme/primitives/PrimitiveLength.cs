namespace scheme;

public class PrimitiveLength : Primitive
{
    public override string Name()
    {
        return "length";
    }

    public override string Info()
    {
        return
            "Syntax: (length list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the number of elements in the proper list. It is an error if the list is not a proper list.\n" +
            "Example:\n" +
            "  (length '(a b c)) => 3\n" +
            "  (length '()) => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        // (define (length x)
        //   (let loop ((x x) (n 0))
        //     (if (null? x)
        // 	n
        // 	(loop (cdr x) (+ n 1)))))
        
        CheckArgs(pos, arguments, 1, 1);
        
        var head = arguments[0];
        var result = 0;
        while (head != Value.NIL)
        {
            head = Value.AsPair(head).cdr;
            result++;
        }
        return (long) result;
    }
}
