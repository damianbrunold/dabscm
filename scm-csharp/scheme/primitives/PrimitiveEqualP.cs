namespace scheme;

public class PrimitiveEqualP : Primitive
{
    public override string Name()
    {
        return "equal?";
    }

    public override string Info()
    {
        return
            "Syntax: (equal? obj1 obj2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj1 and obj2 have the same structure and contents (deep equality). Recursively compares pairs, vectors, and strings.\n" +
            "Example:\n" +
            "  (equal? '(a b c) '(a b c)) => #t\n" +
            "  (equal? \"abc\" \"abc\") => #t\n" +
            "  (equal? '(a b) '(a c)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return Equal(arguments[0], arguments[1]);
    }

    //(define (equal? x y)
    //  (cond
    //   ((eqv? x y))
    //   ((pair? x)
    //    (and (pair? y)
    //         (equal? (car x) (car y))
    //         (equal? (cdr x) (cdr y))))
    //   ((string? x) (and (string? y) (string=? x y)))
    //   ((vector? x)
    //    (and (vector? y)
    //	       (let ((n (vector-length x)))
    //           (and (= (vector-length y) n)
    //                (let loop ((i 0))
    //                  (or (= i n)
    //                      (and (equal? (vector-ref x i) (vector-ref y i))
    //                           (loop (+ i 1)))))))))
    //   (else #f)))

    public static bool Equal(object a, object b)
    {
        if (PrimitiveEqvP.Eqv(a, b))
        {
            return true;
        }

        if (Value.IsPair(a)
            && Value.IsPair(b)
            && Equal(Value.AsPair(a).car, Value.AsPair(b).car)
            && Equal(Value.AsPair(a).cdr, Value.AsPair(b).cdr))
        {
            return true;
        }

        if (Value.IsString(a) && Value.IsString(b))
        {
            char[] aa = Value.AsString(a);
            char[] bb = Value.AsString(b);
            if (aa.Length == bb.Length)
            {
                bool different = false;
                for (var i = 0; i < aa.Length; i++)
                {
                    if (aa[i] != bb[i])
                    {
                        different = true;
                        break;
                    }
                }
                if (!different) return true;
            }
        }
        
        if (Value.IsRecord(a) && Value.IsRecord(b))
        {
            Record ra = Value.AsRecord(a);
            Record rb = Value.AsRecord(b);
            if (ra.Fields.Length != rb.Fields.Length) return false;
            for (int i = 0; i < ra.Fields.Length; i++)
                if (!Equal(ra.Fields[i], rb.Fields[i])) return false;
            return true;
        }

        if (Value.IsVector(a) && Value.IsVector(b))
        {
            object[] aa = Value.AsVector(a);
            object[] bb = Value.AsVector(b);
            if (aa.Length == bb.Length)
            {
                bool different = false;
                for (var i = 0; i < aa.Length; i++)
                {
                    if (!Equal(aa[i], bb[i]))
                    {
                        different = true;
                        break;
                    }
                }
                if (!different) return true;
            }
        }

        if (Value.IsBytevector(a) && Value.IsBytevector(b))
        {
            byte[] aa = Value.AsBytevector(a);
            byte[] bb = Value.AsBytevector(b);
            if (aa.Length == bb.Length)
            {
                bool different = false;
                for (var i = 0; i < aa.Length; i++)
                {
                    if (aa[i] != bb[i])
                    {
                        different = true;
                        break;
                    }
                }
                if (!different) return true;
            }
        }

        return false;
    }
}
