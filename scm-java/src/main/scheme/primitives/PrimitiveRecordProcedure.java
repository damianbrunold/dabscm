package scheme.primitives;

import scheme.*;
import scheme.Record;

// The procedures of define-record-type as primitives, so that calling an
// accessor or predicate costs one primitive call instead of a closure
// call plus record?/record-type/record-ref.
public class PrimitiveRecordProcedure extends Primitive {
    @Override
    public String name() {
        return "%record-procedure";
    }

    @Override
    public String info() {
        return "Syntax: (%record-procedure kind type a b)\n" +
               "Library: (scheme base)\n" +
               "Description: Makes a define-record-type procedure for record type type. kind is\n" +
               "constructor (a: vector of field indexes per argument, b: record size),\n" +
               "predicate, accessor or modifier (a: field index, b: field tag).\n" +
               "Example:\n" +
               "  ((%record-procedure 'predicate type #f #f) obj) => #t or #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 4, 4);
        String kind = Value.asSymbol(arguments[0]);
        Object type = arguments[1];
        switch (kind) {
            case "constructor": {
                Object[] iv = Value.asVector(arguments[2]);
                int[] indexes = new int[iv.length];
                for (int i = 0; i < iv.length; i++) indexes[i] = IntegerMath.toInt(iv[i]);
                return new Constructor(type, indexes, IntegerMath.toInt(arguments[3]));
            }
            case "predicate":
                return new Predicate(type);
            case "accessor":
                return new Accessor(type, IntegerMath.toInt(arguments[2]), arguments[3]);
            case "modifier":
                return new Modifier(type, IntegerMath.toInt(arguments[2]), arguments[3]);
            default:
                throw new SchemeError(pos, "%record-procedure: unknown kind ~s", arguments[0]);
        }
    }

    private static boolean isInstance(Object thing, Object type) {
        return thing instanceof Record && ((Record) thing).fields.length > 0
            && ((Record) thing).fields[0] == type;
    }

    private static final class Constructor extends Primitive {
        private final Object type;
        private final int[] indexes;
        private final int size;

        Constructor(Object type, int[] indexes, int size) {
            this.type = type;
            this.indexes = indexes;
            this.size = size;
        }

        @Override public String name() { return "record-constructor"; }
        @Override public String info() { return ""; }

        @Override
        public Object apply(SourcePos pos, Object[] arguments) {
            if (arguments.length != indexes.length)
                throw new SchemeError(pos, new ErrorObject("wrong number of arguments to constructor",
                                                           new Object[] { type, Pair.list(arguments) }));
            Record r = new Record(size);
            r.fields[0] = type;
            for (int i = 0; i < indexes.length; i++) r.fields[indexes[i]] = arguments[i];
            return r;
        }
    }

    private static final class Predicate extends Primitive {
        private final Object type;

        Predicate(Object type) { this.type = type; }

        @Override public String name() { return "record-predicate"; }
        @Override public String info() { return ""; }

        @Override
        public Object apply(SourcePos pos, Object[] arguments) {
            checkArgs(pos, arguments, 1, 1);
            return isInstance(arguments[0], type);
        }
    }

    private static final class Accessor extends Primitive {
        private final Object type;
        private final int index;
        private final Object tag;

        Accessor(Object type, int index, Object tag) {
            this.type = type;
            this.index = index;
            this.tag = tag;
        }

        @Override public String name() { return "record-accessor"; }
        @Override public String info() { return ""; }

        @Override
        public Object apply(SourcePos pos, Object[] arguments) {
            checkArgs(pos, arguments, 1, 1);
            Object thing = arguments[0];
            if (!isInstance(thing, type))
                throw new SchemeError(pos, new ErrorObject("accessor applied to bad value",
                                                           new Object[] { type, tag, thing }));
            return ((Record) thing).fields[index];
        }
    }

    private static final class Modifier extends Primitive {
        private final Object type;
        private final int index;
        private final Object tag;

        Modifier(Object type, int index, Object tag) {
            this.type = type;
            this.index = index;
            this.tag = tag;
        }

        @Override public String name() { return "record-modifier"; }
        @Override public String info() { return ""; }

        @Override
        public Object apply(SourcePos pos, Object[] arguments) {
            checkArgs(pos, arguments, 2, 2);
            Object thing = arguments[0];
            if (!isInstance(thing, type))
                throw new SchemeError(pos, new ErrorObject("modifier applied to bad value",
                                                           new Object[] { type, tag, thing }));
            ((Record) thing).fields[index] = arguments[1];
            return new Values();
        }
    }
}
