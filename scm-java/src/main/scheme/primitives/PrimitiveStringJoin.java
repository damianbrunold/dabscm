package scheme.primitives;

import scheme.*;

public class PrimitiveStringJoin extends Primitive {
    @Override
    public String name() {
        return "string-join";
    }

    @Override
    public String info() {
        return "Syntax: (string-join strs delim grammar?)\n" +
               "Library: (scm string)\n" +
               "Description: Concatenates a list of strings strs with delim as the separator. The optional grammar argument may be 'infix (default), 'prefix, or 'suffix.\n" +
               "Example:\n" +
               "  (string-join '(\"a\" \"b\" \"c\") \"-\") => \"a-b-c\"\n" +
               "  (string-join '(\"x\" \"y\") \",\" 'suffix) => \"x,y,\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        Object lst = arguments[0];
        char[] sep = new char[] { ' ' };
        String kind = "infix";
        if (arguments.length > 1) {
            sep = Value.asString(arguments[1]);
        }
        if (arguments.length > 2) {
            kind = Value.asSymbol(arguments[2]);
        }
        StringBuilder result = new StringBuilder();
        if (kind.equals("infix")) {
            var first = true;
            while (lst != Value.NIL) {
                if (!first) result.append(sep);
                Object obj = Value.asPair(lst).car;
                if (Value.isString(obj)) {
                    result.append(Value.asString(obj));
                } else if (Value.isSymbol(obj)) {
                    result.append(Value.asSymbol(obj));
                } else {
                    result.append(Value.displayRep(obj));
                }
                lst = Value.asPair(lst).cdr;
                first = false;
            }
        } else if (kind.equals("suffix")) {
            while (lst != Value.NIL) {
                Object obj = Value.asPair(lst).car;
                if (Value.isString(obj)) {
                    result.append(Value.asString(obj));
                } else if (Value.isSymbol(obj)) {
                    result.append(Value.asSymbol(obj));
                } else {
                    result.append(Value.displayRep(obj));
                }
                result.append(sep);
                lst = Value.asPair(lst).cdr;
            }
        } else if (kind.equals("prefix")) {
            while (lst != Value.NIL) {
                result.append(sep);
                Object obj = Value.asPair(lst).car;
                if (Value.isString(obj)) {
                    result.append(Value.asString(obj));
                } else if (Value.isSymbol(obj)) {
                    result.append(Value.asSymbol(obj));
                } else {
                    result.append(Value.displayRep(obj));
                }
                lst = Value.asPair(lst).cdr;
            }
        }
        return result.toString().toCharArray();
    }
}
