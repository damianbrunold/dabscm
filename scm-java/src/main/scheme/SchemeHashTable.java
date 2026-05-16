package scheme;

import scheme.primitives.PrimitiveEqP;
import scheme.primitives.PrimitiveEqvP;
import scheme.primitives.PrimitiveEqualP;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class SchemeHashTable {

    public enum EqualityMode { EQ, EQV, EQUAL }

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
            if (mode == EqualityMode.EQ) {
                return System.identityHashCode(value);
            }
            return schemeHash(value, 0);
        }

        @Override
        public boolean equals(Object other) {
            if (!(other instanceof SchemeKey)) return false;
            SchemeKey o = (SchemeKey) other;
            if (mode == EqualityMode.EQ) return PrimitiveEqP.eq(value, o.value);
            if (mode == EqualityMode.EQV) return PrimitiveEqvP.eqv(value, o.value);
            return PrimitiveEqualP.equal(value, o.value);
        }
    }
}
