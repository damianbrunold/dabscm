package scheme.primitives;

import scheme.*;

import java.io.*;

public class PrimitiveOpenBinaryInputFile extends Primitive {
    @Override public String name() { return "open-binary-input-file"; }
    @Override public String info() {
        return "Syntax: (open-binary-input-file filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Opens the named file for binary input and returns a binary input port. Raises a file-error if the file cannot be opened.\n" +
               "Example:\n" +
               "  (let ((p (open-binary-input-file \"data.bin\")))\n" +
               "    (read-u8 p))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String filename = new String(Value.asString(arguments[0]));
        if (!new File(filename).exists())
            throw new SchemeError(pos, new FileErrorObject("open-binary-input-file: file not found", new Object[] { filename }));
        try {
            return new BinaryInputStream(new FileInputStream(filename));
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-binary-input-file: io error", new Object[] { filename }));
        }
    }
}
