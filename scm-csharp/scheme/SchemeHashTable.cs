using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace scheme;

public enum EqualityMode { Eq, Eqv, Equal }

public class SchemeHashTable
{
    public EqualityMode Mode;
    public object? Comparator;
    private Dictionary<SchemeKey, object> map;

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
        if (Mode == EqualityMode.Eq)
        {
            if (Value is bool || Value is long) return Value.GetHashCode();
            return RuntimeHelpers.GetHashCode(Value);
        }
        return SchemeHashTable.SchemeHash(Value);
    }

    public override bool Equals(object? obj)
    {
        if (obj is SchemeKey other) return Equals(other);
        return false;
    }

    public bool Equals(SchemeKey other)
    {
        if (Mode == EqualityMode.Eq) return PrimitiveEqP.Eq(Value, other.Value);
        if (Mode == EqualityMode.Eqv) return PrimitiveEqvP.Eqv(Value, other.Value);
        return PrimitiveEqualP.Equal(Value, other.Value);
    }
}
