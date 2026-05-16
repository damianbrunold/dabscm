package scheme.primitives;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

import scheme.*;

public class PrimitiveGetBytes extends Primitive {
    @Override
    public String name() {
        return "get-bytes";
    }

    @Override
    public String info() {
        return "Syntax: (get-bytes obj [encoding])\n" +
               "Library: (scm core)\n" +
               "Description: Returns the byte representation of obj (string, symbol, or bytevector) as a bytevector.\n" +
               "  encoding is an optional string or symbol specifying the character encoding (default: utf-8).\n" +
               "  Supported encodings: utf-8, utf-8-bom, latin-1, utf-16, utf-16-le.\n" +
               "Example:\n" +
               "  (get-bytes \"hello\")\n" +
               "  (get-bytes \"hello\" \"latin-1\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Charset encoding = StandardCharsets.UTF_8;
        if (arguments.length == 2) {
            String encName = Value.isSymbol(arguments[1])
                ? Value.asSymbol(arguments[1])
                : new String(Value.asString(arguments[1]));
            encoding = Encoding.getEncoding(encName);
        }
        if (Value.isString(arguments[0])) {
            return new String(Value.asString(arguments[0])).getBytes(encoding);
        } else if (Value.isSymbol(arguments[0])) {
            return Value.asSymbol(arguments[0]).getBytes(encoding);
        } else if (Value.isBytevector(arguments[0])) {
            return arguments[0];
        } else if (arguments[0] != null) {
            var s = arguments[0].toString();
            return s.getBytes(encoding);
        } else {
            throw new SchemeError(pos, name() + ": Cannot get bytes from value");
        }
    }
}
