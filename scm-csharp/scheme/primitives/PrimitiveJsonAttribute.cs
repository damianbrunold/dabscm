namespace scheme;

public class PrimitiveJsonAttribute : Primitive
{
    public override string Name()
    {
        return "json-attribute";
    }

    public override string Info()
    {
        return
            "Syntax: (json-attribute object name) (json-attribute object name default)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the value of the named attribute from a JSON object. Returns default (or #f) if the attribute does not exist.\n" +
            "Example:\n" +
            "  (let ((obj (json-next-object reader)))\n" +
            "    (json-attribute obj 'name \"unknown\"))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        try
        {
            JsonObject obj = (JsonObject) Value.AsNativeValue(arguments[0]).value;
            string name;
            if (Value.IsSymbol(arguments[1]))
            {
                name = Value.AsSymbol(arguments[1]);
            }
            else
            {
                name = new String(Value.AsString(arguments[1]));
            }
            if (arguments.Length == 3)
            {
                if (obj.entries.ContainsKey(name))
                {
                    return ToScm(obj.entries[name]);
                }
                return arguments[2];
            }
            else
            {
                if (obj.entries.ContainsKey(name))
                {
                    return ToScm(obj.entries[name]);
                }
                return Value.F;
            }
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "json-attribute failed");
        }
    }

    private object ToScm(JsonValue value)
    {
        if (value.IsString())
        {
            return value.AsString().value.ToCharArray();
        }
        else if (value.IsFalse())
        {
            return Value.F;
        }
        else if (value.IsTrue())
        {
            return Value.T;
        }
        else if (value.IsNull())
        {
            return Value.NIL;
        }
        else if (value.IsNumber())
        {
            double val = value.AsNumber().value;
            if (val == ((double) ((long) val)))
            {
                return (long) val;
            }
            else
            {
                return val;
            }
        }
        else if (value.IsObject())
        {
            return new NativeValue(value);
        }
        else if (value.IsList())
        {
            var list = new object[value.AsList().elements.Count];
            for (var i = 0; i < value.AsList().elements.Count; i++)
            {
                list[i] = ToScm(value.AsList().elements[i]);
            }
            return Pair.List(list);
        }
        return Value.F;
    }
}
