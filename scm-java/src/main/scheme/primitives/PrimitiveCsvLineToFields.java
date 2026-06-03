
package scheme.primitives;

import scheme.*;

public class PrimitiveCsvLineToFields extends Primitive {
    @Override
    public String name() {
        return "csv-line->fields";
    }

    @Override
    public String info() {
        return "Syntax: (csv-line->fields str sep) (csv-line->fields str sep 'trim)\n" +
               "Library: (scm core)\n" +
               "Description: Splits a CSV line string using the given separator, stripping surrounding double-quotes from each field, and returns the fields as a vector. When 'trim is given as a third argument, also trims whitespace from each field.\n" +
               "Example:\n" +
               "  (csv-line->fields \"a,b,c\" \",\") => #(\"a\" \"b\" \"c\")\n" +
               "  (csv-line->fields \"\\\"hello\\\",world\" \",\") => #(\"hello\" \"world\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        String s = new String(Value.asString(arguments[0]));
        String sep = new String(Value.asString(arguments[1]));
        boolean trim = false;
        if (arguments.length > 2 && arguments[2].equals("trim")) {
            trim = true;
        }
        String[] parts = s.split(sep);
        Object[] result = new Object[parts.length];

        for (int i = 0; i < parts.length; i++) {
            String part = parts[i];
            if (part.startsWith("\"") && part.endsWith("\"")) {
                part = part.substring(1, part.length() - 1);
            }
            if (trim) {
                part = part.trim();
            }
            result[i] = part.toCharArray();
        }
        return result;
    }
}
