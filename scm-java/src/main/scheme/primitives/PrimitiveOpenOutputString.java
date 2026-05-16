package scheme.primitives;

import scheme.*;

import java.io.StringWriter;

public class PrimitiveOpenOutputString extends Primitive {
    @Override
    public String name() {
        return "open-output-string";
    }

    @Override
    public String info() {
        return "Syntax: (open-output-string)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a textual output port that accumulates characters written to it. Use get-output-string to retrieve the accumulated string.\n" +
               "Example:\n" +
               "  (let ((p (open-output-string)))\n" +
               "    (write-char #\\h p)\n" +
               "    (get-output-string p)) => \"h\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return new TextOutputStream(new StringWriter());
    }
}
