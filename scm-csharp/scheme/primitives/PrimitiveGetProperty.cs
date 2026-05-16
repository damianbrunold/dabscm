namespace scheme;

public class PrimitiveGetProperty : Primitive
{
    //(define (get-property obj name)
    //  (let loop ((obj obj))
    //    (if (null? obj)
    //        #f
    //        (if (pair? (car obj))
    //            (if (eq? (caar obj) name)
    //                (cadar obj)
    //                (loop (cdr obj)))
    //            (if (eq? (car obj) name)
    //                name
    //                (loop (cdr obj)))))))

    public override string Name()
    {
        return "get-property";
    }

    public override string Info()
    {
        return
            "Syntax: (get-property lst name) (get-property lst name default)\n" +
            "Library: (scm core)\n" +
            "Description: Searches for name in the property list lst. Each element may be a symbol (flag) or a (name value) pair. Returns the value, the symbol itself (for flags), or default/#f if not found.\n" +
            "Example:\n" +
            "  (get-property '((x 1) (y 2)) 'x) => 1\n" +
            "  (get-property '(foo bar) 'foo) => foo";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        var lst = arguments[0];
        var val = arguments[1];
        var result = GetProperty(lst, val, Value.F);
        if (result.Equals(Value.F) && arguments.Length == 3)
        {
            return arguments[2];
        }
        return result;
    }

    public static object GetProperty(object lst, object name, object defaultvalue)
    {
        while (lst != Value.NIL)
        {
            var cur = Value.AsPair(lst);
            if (Value.IsPair(cur.car))
            {
                Pair sub = Value.AsPair(cur.car);
                if (sub.car.Equals(name))
                {
                    return Value.AsPair(sub.cdr).car;
                }
            }
            else
            {
                if (cur.car.Equals(name))
                {
                    return cur.car;
                }
            }
            lst = cur.cdr;
        }
        return defaultvalue;
    }
}
