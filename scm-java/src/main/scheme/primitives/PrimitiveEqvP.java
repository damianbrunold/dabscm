package scheme.primitives;

import scheme.*;

public class PrimitiveEqvP extends Primitive {
    @Override
    public String name() {
        return "eqv?";
    }

    @Override
    public String info() {
        return "Syntax: (eqv? obj1 obj2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj1 and obj2 are operationally equivalent. Numbers are eqv? if they have the same exactness and are numerically equal.\n" +
               "Example:\n" +
               "  (eqv? 'a 'a) => #t\n" +
               "  (eqv? 1 1) => #t\n" +
               "  (eqv? 1 1.0) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        return eqv(arguments[0], arguments[1]);
    }

    //(define (eqv? x y)
    //  (cond
    //   ((eq? x y))
    //   ((number? x)
    //    (and (number? y)
    //         (if (exact? x)
    //             (and (exact? y) (= x y))
    //	           (and (inexact? y) (= x y)))))
    //   ((char? x) (and (char? y) (char=? x y)))
    //   (else #f)))
    
    public static boolean eqv(Object a, Object b) {
        if (PrimitiveEqP.eq(a, b)) {
            return true;
        }
        
        if (Value.isInteger(a) && Value.isInteger(b)) {
            return IntegerMath.genericEquals(a, b);
        }
        
        if (Value.isRational(a) && Value.isRational(b)) {
            return Value.asRational(a).equals(Value.asRational(b));
        }

        if (Value.isReal(a) && Value.isReal(b)) {
            return Value.asReal(a).equals(Value.asReal(b));
        }

        if (Value.isComplex(a) && Value.isComplex(b)) {
            return Value.asComplex(a).equals(Value.asComplex(b));
        }

        if (Value.isChar(a) && Value.isChar(b)) {
            return Value.asChar(a).equals(Value.asChar(b));
        }

        return false;
    }
}
