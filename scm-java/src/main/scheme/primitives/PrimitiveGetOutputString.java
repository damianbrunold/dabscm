package scheme.primitives;

import scheme.*;

import java.io.StringWriter;

public class PrimitiveGetOutputString extends Primitive {
    @Override
    public String name() {
        return "get-output-string";
    }

    @Override
    public String info() {
        return "Syntax: (get-output-string port)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a string consisting of the characters that have been output to the given string output port (created with open-output-string).\n" +
               "Example:\n" +
               "  (let ((p (open-output-string)))\n" +
               "    (write-char #\\A p)\n" +
               "    (get-output-string p)) => \"A\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        java.io.Writer port = Value.asOutputPort(arguments[0]);
        StringWriter writer;
        if (port instanceof TextOutputStream)
            writer = (StringWriter) ((TextOutputStream) port).getInner();
        else
            writer = (StringWriter) port;
        return writer.toString().toCharArray();
    }
}
