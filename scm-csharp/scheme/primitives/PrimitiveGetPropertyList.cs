namespace scheme;

public class PrimitiveGetPropertyList : Primitive
{
    //(define (get-property-list obj name)
    //  (let loop ((obj obj))
    //    (if (null? obj)
    //        #f
    //        (if (pair? (car obj))
    //            (if (eq? (caar obj) name)
    //                (cdar obj)
    //                (loop (cdr obj)))
    //            (loop (cdr obj))))))

    public override string Name()
    {
        return "get-property-list";
    }

    public override string Info()
    {
        return
            "Syntax: (get-property-list lst name) (get-property-list lst name default)\n" +
            "Library: (scm core)\n" +
            "Description: Searches for name in the property list lst. Returns the cdr of the matching pair (the full value list), or default/#f if not found.\n" +
            "Example:\n" +
            "  (get-property-list '((x 1 2) (y 3)) 'x) => (1 2)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        var lst = arguments[0];
        var val = arguments[1];
        while (lst != Value.NIL)
        {
            Pair pair = Value.AsPair(lst);
            if (Value.IsPair(pair.car))
            {
                Pair sub = Value.AsPair(pair.car);
                if (sub.car.Equals(val))
                {
                    return sub.cdr;
                }
            }
            else
            {
                if (pair.car.Equals(val))
                {
                    return pair.car;
                }
            }
            lst = pair.cdr;
        }
        if (arguments.Length == 3) return arguments[2];
        return Value.F;
    }
}
