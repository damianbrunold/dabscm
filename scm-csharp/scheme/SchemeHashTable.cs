using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace scheme;

// StringCi: string-ci=? (keys case-folded), CharCi: char-ci=?, Numeric: =
// (keys numbers; 1 and 1.0 are the same key)
public enum EqualityMode { Eq, Eqv, Equal, StringCi, CharCi, Numeric }

public class SchemeHashTable
{
    public EqualityMode Mode;
    public object? Comparator;
    private Dictionary<SchemeKey, object> map;

    // the mode a symbol names (eq eqv equal string-ci char-ci numeric), or
    // null: (srfi 69)/(srfi 125) pass the mode for their equivalence
    public static EqualityMode? ModeOfSymbol(object o)
    {
        if (!Value.IsSymbol(o)) return null;
        switch (Value.AsSymbol(o))
        {
            case "eq": return EqualityMode.Eq;
            case "eqv": return EqualityMode.Eqv;
            case "equal": return EqualityMode.Equal;
            case "string-ci": return EqualityMode.StringCi;
            case "char-ci": return EqualityMode.CharCi;
            case "numeric": return EqualityMode.Numeric;
            default: return null;
        }
    }

    private static readonly PrimitiveNumequal NumEqual = new PrimitiveNumequal();

    // keys of another type than the mode's compare as with equal?
    // (string-ci, numeric) or eqv? (char-ci), as in dabscm native

    private static bool IsNumber(object v) =>
        Value.IsInteger(v) || Value.IsReal(v) || Value.IsRational(v) || v is Complex;

    // the double value of a number (for hashing under =)
    private static double RealValue(object v)
    {
        if (Value.IsReal(v)) return Value.AsReal(v);
        if (Value.IsRational(v)) return Value.AsRational(v).ToDouble();
        if (Value.IsInteger(v)) return IntegerMath.ToDouble(v);
        if (v is Complex c) return RealValue(c.Real);
        return 0.0;
    }

    internal static int NumericHash(object v)
    {
        if (!IsNumber(v)) return SchemeHash(v);
        double d = RealValue(v);
        if (d == 0.0) return 0; // 0.0, -0.0 and 0
        if (double.IsNaN(d)) return 1;
        return d.GetHashCode();
    }

    internal static bool NumericEquals(object a, object b)
    {
        if (!IsNumber(a) || !IsNumber(b)) return PrimitiveEqualP.Equal(a, b);
        return NumEqual.Apply(null, new object[] { a, b }) is bool r && r;
    }

    private static string Fold(object v) => UnicodeCaseMap.ToFold(new string(Value.AsString(v)));

    internal static int StringCiHash(object v) =>
        Value.IsString(v) ? Fold(v).GetHashCode() : SchemeHash(v);

    internal static bool StringCiEquals(object a, object b) =>
        Value.IsString(a) && Value.IsString(b) ? Fold(a) == Fold(b) : PrimitiveEqualP.Equal(a, b);

    internal static int CharCiHash(object v) =>
        Value.IsChar(v) ? UnicodeCaseMap.Foldcase(Value.AsChar(v)).GetHashCode() : SchemeHash(v);

    internal static bool CharCiEquals(object a, object b) =>
        Value.IsChar(a) && Value.IsChar(b)
            ? UnicodeCaseMap.Foldcase(Value.AsChar(a)) == UnicodeCaseMap.Foldcase(Value.AsChar(b))
            : PrimitiveEqvP.Eqv(a, b);

    public SchemeHashTable(EqualityMode mode)
    {
        Mode = mode;
        map = new Dictionary<SchemeKey, object>();
    }

    private SchemeKey MakeKey(object value) => new SchemeKey { Value = value, Mode = Mode };

    public bool Contains(object key) => map.ContainsKey(MakeKey(key));

    public object? Get(object key)
    {
        if (map.TryGetValue(MakeKey(key), out var result)) return result;
        return null;
    }

    public void Set(object key, object value) => map[MakeKey(key)] = value;

    public bool Delete(object key) => map.Remove(MakeKey(key));

    public int Size() => map.Count;

    public List<object> GetKeys()
    {
        var result = new List<object>();
        foreach (var kv in map) result.Add(kv.Key.Value);
        return result;
    }

    public List<object> GetValues()
    {
        var result = new List<object>();
        foreach (var kv in map) result.Add(kv.Value);
        return result;
    }

    public object ToAlist()
    {
        object result = Value.NIL;
        foreach (var kv in map)
        {
            result = new Pair(new Pair(kv.Key.Value, kv.Value), result);
        }
        return result;
    }

    public void Clear() => map.Clear();

    public SchemeHashTable Copy()
    {
        var copy = new SchemeHashTable(Mode);
        copy.Comparator = Comparator;
        foreach (var kv in map) copy.map[kv.Key] = kv.Value;
        return copy;
    }

    public IEnumerable<KeyValuePair<SchemeKey, object>> Entries() => map;

    public static int SchemeHash(object value, int depth = 0)
    {
        if (depth > 8) return 0;
        if (Value.IsSymbol(value)) return Value.AsSymbol(value).GetHashCode();
        if (Value.IsString(value)) return new string(Value.AsString(value)).GetHashCode();
        if (Value.IsChar(value)) return Value.AsChar(value).GetHashCode();
        if (Value.IsInteger(value)) return value.GetHashCode();
        if (Value.IsReal(value)) return Value.AsReal(value).GetHashCode();
        if (Value.IsBoolean(value)) return value.GetHashCode();
        if (Value.IsNil(value)) return 0;
        if (Value.IsPair(value))
        {
            var pair = Value.AsPair(value);
            int h = SchemeHash(pair.car!, depth + 1);
            h = h * 31 ^ SchemeHash(pair.cdr!, depth + 1);
            return h;
        }
        if (Value.IsVector(value))
        {
            var vec = Value.AsVector(value);
            int h = 0;
            int limit = Math.Min(vec.Length, 8);
            for (int i = 0; i < limit; i++)
                h = h * 31 ^ SchemeHash(vec[i], depth + 1);
            return h;
        }
        return RuntimeHelpers.GetHashCode(value);
    }
}

public struct SchemeKey : IEquatable<SchemeKey>
{
    public object Value;
    public EqualityMode Mode;

    public override int GetHashCode()
    {
        switch (Mode)
        {
            case EqualityMode.Eq:
                if (Value is bool || Value is long) return Value.GetHashCode();
                return RuntimeHelpers.GetHashCode(Value);
            case EqualityMode.StringCi: return SchemeHashTable.StringCiHash(Value);
            case EqualityMode.CharCi: return SchemeHashTable.CharCiHash(Value);
            case EqualityMode.Numeric: return SchemeHashTable.NumericHash(Value);
            default: return SchemeHashTable.SchemeHash(Value);
        }
    }

    public override bool Equals(object? obj)
    {
        if (obj is SchemeKey other) return Equals(other);
        return false;
    }

    public bool Equals(SchemeKey other)
    {
        switch (Mode)
        {
            case EqualityMode.Eq: return PrimitiveEqP.Eq(Value, other.Value);
            case EqualityMode.Eqv: return PrimitiveEqvP.Eqv(Value, other.Value);
            case EqualityMode.StringCi: return SchemeHashTable.StringCiEquals(Value, other.Value);
            case EqualityMode.CharCi: return SchemeHashTable.CharCiEquals(Value, other.Value);
            case EqualityMode.Numeric: return SchemeHashTable.NumericEquals(Value, other.Value);
            default: return PrimitiveEqualP.Equal(Value, other.Value);
        }
    }
}
