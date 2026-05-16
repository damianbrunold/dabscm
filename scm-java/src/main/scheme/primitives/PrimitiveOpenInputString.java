package scheme.primitives;

import scheme.*;

import java.io.*;

public class PrimitiveOpenInputString extends Primitive {
    @Override
    public String name() {
        return "open-input-string";
    }

    @Override
    public String info() {
        return "Syntax: (open-input-string string)\n" +
               "Library: (scheme base)\n" +
               "Description: Takes a string and returns a textual input port that delivers characters from the string.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"hello\"))\n" +
               "  (read-char p) => #\\h";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String text = new String(Value.asString(arguments[0]));
        return new TextStream(new PushbackReader(new StringReader(text)), null);
    }
}
