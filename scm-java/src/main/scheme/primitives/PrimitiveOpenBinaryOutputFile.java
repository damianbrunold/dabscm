package scheme.primitives;

import scheme.*;

import java.nio.file.Files;

public class PrimitiveOpenBinaryOutputFile extends Primitive {
    @Override public String name() { return "open-binary-output-file"; }
    @Override public String info() {
        return "Syntax: (open-binary-output-file filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Opens the named file for binary output and returns a binary output port. Creates or truncates the file. Raises a file-error on failure.\n" +
               "Example:\n" +
               "  (let ((p (open-binary-output-file \"out.bin\")))\n" +
               "    (write-u8 42 p))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String filename = new String(Value.asString(arguments[0]));
        try {
            return new BinaryOutputStream(Files.newOutputStream(LongPath.of(filename)), false);
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-binary-output-file: io failure", new Object[] { filename }));
        }
    }
}
