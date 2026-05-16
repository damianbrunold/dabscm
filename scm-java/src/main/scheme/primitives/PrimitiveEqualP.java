package scheme.primitives;

import scheme.*;

public class PrimitiveEqualP extends Primitive {
    @Override
    public String name() {
        return "equal?";
    }

    @Override
    public String info() {
        return "Syntax: (equal? obj1 obj2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj1 and obj2 have the same structure and contents (deep equality). Recursively compares pairs, vectors, and strings.\n" +
               "Example:\n" +
               "  (equal? '(a b c) '(a b c)) => #t\n" +
               "  (equal? \"abc\" \"abc\") => #t\n" +
               "  (equal? '(a b) '(a c)) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        return equal(arguments[0], arguments[1]);
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

    public static boolean equal(Object a, Object b) {
        if (PrimitiveEqvP.eqv(a, b)) {
            return true;
        }

        if (Value.isPair(a)
            && Value.isPair(b)
            && equal(Value.asPair(a).car, Value.asPair(b).car)
            && equal(Value.asPair(a).cdr, Value.asPair(b).cdr)) {
            return true;
        }

        if (Value.isString(a) && Value.isString(b)) {
            char[] aa = Value.asString(a);
            char[] bb = Value.asString(b);
            if (aa.length == bb.length) {
                boolean different = false;
                for (var i = 0; i < aa.length; i++) {
                    if (aa[i] != bb[i]) {
                        different = true;
                        break;
                    }
                }
                if (!different) return true;
            }
        }
        
        if (Value.isRecord(a) && Value.isRecord(b)) {
            scheme.Record ra = Value.asRecord(a);
            scheme.Record rb = Value.asRecord(b);
            if (ra.fields.length != rb.fields.length) return false;
            for (int i = 0; i < ra.fields.length; i++)
                if (!equal(ra.fields[i], rb.fields[i])) return false;
            return true;
        }

        if (Value.isVector(a) && Value.isVector(b)) {
            Object[] aa = Value.asVector(a);
            Object[] bb = Value.asVector(b);
            if (aa.length == bb.length) {
                boolean different = false;
                for (int i = 0; i < aa.length; i++) {
                    if (!equal(aa[i], bb[i])) {
                        different = true;
                        break;
                    }
                }
                if (!different) return true;
            }
        }

        if (Value.isBytevector(a) && Value.isBytevector(b)) {
            byte[] aa = Value.asBytevector(a);
            byte[] bb = Value.asBytevector(b);
            if (aa.length == bb.length) {
                boolean different = false;
                for (var i = 0; i < aa.length; i++) {
                    if (aa[i] != bb[i]) {
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
