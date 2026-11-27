package scheme;

import scheme.primitives.PrimitiveEqP;
import scheme.primitives.PrimitiveEqvP;
import scheme.primitives.PrimitiveEqualP;
import scheme.primitives.PrimitiveNumequal;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class SchemeHashTable {

    // STRING_CI: string-ci=? (keys case-folded), CHAR_CI: char-ci=?,
    // NUMERIC: = (keys numbers; 1 and 1.0 are the same key)
    public enum EqualityMode { EQ, EQV, EQUAL, STRING_CI, CHAR_CI, NUMERIC }

    // the mode a symbol names (eq eqv equal string-ci char-ci numeric), or
    // null: (srfi 69)/(srfi 125) pass the mode for their equivalence
    public static EqualityMode modeOfSymbol(Object o) {
        if (!Value.isSymbol(o)) return null;
        switch (o.toString()) {
            case "eq": return EqualityMode.EQ;
            case "eqv": return EqualityMode.EQV;
            case "equal": return EqualityMode.EQUAL;
            case "string-ci": return EqualityMode.STRING_CI;
            case "char-ci": return EqualityMode.CHAR_CI;
            case "numeric": return EqualityMode.NUMERIC;
            default: return null;
        }
    }

    private static final PrimitiveNumequal NUMEQUAL = new PrimitiveNumequal();

    // keys of another type than the mode's compare as with equal?
    // (string-ci, numeric) or eqv? (char-ci), as in dabscm native

    // the double value of a number (for hashing under =)
    private static double realValue(Object v) {
        if (Value.isReal(v)) return Value.asReal(v);
        if (Value.isRational(v)) return Value.asRational(v).toDouble();
        if (Value.isInteger(v)) return IntegerMath.toDouble(v);
        if (v instanceof Complex) return realValue(((Complex) v).real);
        return 0.0;
    }

    private static boolean isNumber(Object v) {
        return Value.isInteger(v) || Value.isReal(v) || Value.isRational(v) || v instanceof Complex;
    }

    static int numericHash(Object v) {
        if (!isNumber(v)) return schemeHash(v, 0);
        double d = realValue(v);
        if (d == 0.0) return 0; // 0.0, -0.0 and 0
        if (Double.isNaN(d)) return 1;
        return Double.hashCode(d);
    }

    static boolean numericEquals(Object a, Object b) {
        if (!isNumber(a) || !isNumber(b)) return PrimitiveEqualP.equal(a, b);
        return Boolean.TRUE.equals(NUMEQUAL.apply(null, new Object[] { a, b }));
    }

    static String fold(Object v) {
        return UnicodeCaseMap.toFold(new String(Value.asString(v)));
    }

    static int stringCiHash(Object v) {
        return Value.isString(v) ? fold(v).hashCode() : schemeHash(v, 0);
    }

    static boolean stringCiEquals(Object a, Object b) {
        if (Value.isString(a) && Value.isString(b)) return fold(a).equals(fold(b));
        return PrimitiveEqualP.equal(a, b);
    }

    static int charCiHash(Object v) {
        return Value.isChar(v) ? UnicodeCaseMap.foldChar(Value.asChar(v)) : schemeHash(v, 0);
    }

    static boolean charCiEquals(Object a, Object b) {
        if (Value.isChar(a) && Value.isChar(b))
            return UnicodeCaseMap.foldChar(Value.asChar(a)) == UnicodeCaseMap.foldChar(Value.asChar(b));
        return PrimitiveEqvP.eqv(a, b);
    }

    public EqualityMode mode;
    public Object comparator;
    private HashMap<SchemeKey, Object> map;

    public SchemeHashTable(EqualityMode mode) {
        this.mode = mode;
        this.map = new HashMap<>();
    }

    private SchemeKey makeKey(Object value) {
        return new SchemeKey(value, mode);
    }

    public boolean contains(Object key) {
        return map.containsKey(makeKey(key));
    }

    public Object get(Object key) {
        return map.get(makeKey(key));
    }

    public void set(Object key, Object value) {
        map.put(makeKey(key), value);
    }

    public boolean delete(Object key) {
        return map.remove(makeKey(key)) != null;
    }

    public int size() {
        return map.size();
    }

    public List<Object> getKeys() {
        List<Object> result = new ArrayList<>();
        for (SchemeKey k : map.keySet()) result.add(k.value);
        return result;
    }

    public List<Object> getValues() {
        return new ArrayList<>(map.values());
    }

    public Object toAlist() {
        Object result = Value.NIL;
        for (Map.Entry<SchemeKey, Object> entry : map.entrySet()) {
            result = new Pair(new Pair(entry.getKey().value, entry.getValue()), result);
        }
        return result;
    }

    public void clear() {
        map.clear();
    }

    public SchemeHashTable copy() {
        SchemeHashTable copy = new SchemeHashTable(mode);
        copy.comparator = this.comparator;
        copy.map.putAll(this.map);
        return copy;
    }

    public Iterable<Map.Entry<SchemeKey, Object>> entries() {
        return map.entrySet();
    }

    public static int schemeHash(Object value, int depth) {
        if (depth > 8) return 0;
        if (Value.isSymbol(value)) return Value.asSymbol(value).hashCode();
        if (Value.isString(value)) return new String(Value.asString(value)).hashCode();
        if (Value.isChar(value)) return Value.asChar(value).hashCode();
        if (Value.isInteger(value)) return value.hashCode();
        if (Value.isReal(value)) return Value.asReal(value).hashCode();
        if (Value.isBoolean(value)) return value.hashCode();
        if (Value.isNil(value)) return 0;
        if (Value.isPair(value)) {
            Pair pair = Value.asPair(value);
            int h = schemeHash(pair.car, depth + 1);
            h = h * 31 ^ schemeHash(pair.cdr, depth + 1);
            return h;
        }
        if (Value.isVector(value)) {
            Object[] vec = Value.asVector(value);
            int h = 0;
            int limit = Math.min(vec.length, 8);
            for (int i = 0; i < limit; i++)
                h = h * 31 ^ schemeHash(vec[i], depth + 1);
            return h;
        }
        return System.identityHashCode(value);
    }

    public static class SchemeKey {
        public final Object value;
        public final EqualityMode mode;

        public SchemeKey(Object value, EqualityMode mode) {
            this.value = value;
            this.mode = mode;
        }

        @Override
        public int hashCode() {
            switch (mode) {
                case EQ: return System.identityHashCode(value);
                case STRING_CI: return stringCiHash(value);
                case CHAR_CI: return charCiHash(value);
                case NUMERIC: return numericHash(value);
                default: return schemeHash(value, 0);
            }
        }

        @Override
        public boolean equals(Object other) {
            if (!(other instanceof SchemeKey)) return false;
            SchemeKey o = (SchemeKey) other;
            switch (mode) {
                case EQ: return PrimitiveEqP.eq(value, o.value);
                case EQV: return PrimitiveEqvP.eqv(value, o.value);
                case STRING_CI: return stringCiEquals(value, o.value);
                case CHAR_CI: return charCiEquals(value, o.value);
                case NUMERIC: return numericEquals(value, o.value);
                default: return PrimitiveEqualP.equal(value, o.value);
            }
        }
    }
}
