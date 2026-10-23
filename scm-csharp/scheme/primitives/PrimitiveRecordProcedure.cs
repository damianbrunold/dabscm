namespace scheme;

// The procedures of define-record-type as primitives, so that calling an
// accessor or predicate costs one primitive call instead of a closure
// call plus record?/record-type/record-ref.
public class PrimitiveRecordProcedure : Primitive
{
    public override string Name()
    {
        return "%record-procedure";
    }

    public override string Info()
    {
        return
            "Syntax: (%record-procedure kind type a b)\n" +
            "Library: (scheme base)\n" +
            "Description: Makes a define-record-type procedure for record type type. kind is\n" +
            "constructor (a: vector of field indexes per argument, b: record size),\n" +
            "predicate, accessor or modifier (a: field index, b: field tag).\n" +
            "Example:\n" +
            "  ((%record-procedure 'predicate type #f #f) obj) => #t or #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 4, 4);
        string kind = Value.AsSymbol(arguments[0]);
        object type = arguments[1];
        switch (kind)
        {
            case "constructor":
            {
                object[] iv = Value.AsVector(arguments[2]);
                int[] indexes = new int[iv.Length];
                for (int i = 0; i < iv.Length; i++) indexes[i] = IntegerMath.ToInt(iv[i]);
                return new Constructor(type, indexes, IntegerMath.ToInt(arguments[3]));
            }
            case "predicate":
                return new Predicate(type);
            case "accessor":
                return new Accessor(type, IntegerMath.ToInt(arguments[2]), arguments[3]);
            case "modifier":
                return new Modifier(type, IntegerMath.ToInt(arguments[2]), arguments[3]);
            default:
                throw new SchemeError(pos, "%record-procedure: unknown kind ~s", arguments[0]);
        }
    }

    private static bool IsInstance(object thing, object type)
    {
        return thing is Record r && r.Fields.Length > 0 && ReferenceEquals(r.Fields[0], type);
    }

    private sealed class Constructor : Primitive
    {
        private readonly object type;
        private readonly int[] indexes;
        private readonly int size;

        public Constructor(object type, int[] indexes, int size)
        {
            this.type = type;
            this.indexes = indexes;
            this.size = size;
        }

        public override string Name() => "record-constructor";
        public override string Info() => "";

        public override object Apply(SourcePos? pos, object[] arguments)
        {
            if (arguments.Length != indexes.Length)
                throw new SchemeError(pos, new ErrorObject("wrong number of arguments to constructor",
                                                           new object[] { type, Pair.List(arguments) }));
            var r = new Record(size);
            r.Fields[0] = type;
            for (int i = 0; i < indexes.Length; i++) r.Fields[indexes[i]] = arguments[i];
            return r;
        }
    }

    private sealed class Predicate : Primitive
    {
        private readonly object type;

        public Predicate(object type) { this.type = type; }

        public override string Name() => "record-predicate";
        public override string Info() => "";

        public override object Apply(SourcePos? pos, object[] arguments)
        {
            CheckArgs(pos, arguments, 1, 1);
            return IsInstance(arguments[0], type);
        }
    }

    private sealed class Accessor : Primitive
    {
        private readonly object type;
        private readonly int index;
        private readonly object tag;

        public Accessor(object type, int index, object tag)
        {
            this.type = type;
            this.index = index;
            this.tag = tag;
        }

        public override string Name() => "record-accessor";
        public override string Info() => "";

        public override object Apply(SourcePos? pos, object[] arguments)
        {
            CheckArgs(pos, arguments, 1, 1);
            object thing = arguments[0];
            if (!IsInstance(thing, type))
                throw new SchemeError(pos, new ErrorObject("accessor applied to bad value",
                                                           new object[] { type, tag, thing }));
            return ((Record)thing).Fields[index];
        }
    }

    private sealed class Modifier : Primitive
    {
        private readonly object type;
        private readonly int index;
        private readonly object tag;

        public Modifier(object type, int index, object tag)
        {
            this.type = type;
            this.index = index;
            this.tag = tag;
        }

        public override string Name() => "record-modifier";
        public override string Info() => "";

        public override object Apply(SourcePos? pos, object[] arguments)
        {
            CheckArgs(pos, arguments, 2, 2);
            object thing = arguments[0];
            if (!IsInstance(thing, type))
                throw new SchemeError(pos, new ErrorObject("modifier applied to bad value",
                                                           new object[] { type, tag, thing }));
            ((Record)thing).Fields[index] = arguments[1];
            return new Values();
        }
    }
}
