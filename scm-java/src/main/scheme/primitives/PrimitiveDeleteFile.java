package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.Path;

import scheme.*;

public class PrimitiveDeleteFile extends Primitive {
    @Override
    public String name() {
        return "delete-file";
    }

    @Override
    public String info() {
        return "Syntax: (delete-file filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Deletes the named file. Returns unspecified if successful, #f if the file could not be deleted.\n" +
               "Example:\n" +
               "  (delete-file \"temp.txt\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var raw = new String(Value.asString(arguments[0]));
        try {
            // LongPath.of can throw InvalidPathException for names the
            // filesystem rejects (e.g. trailing spaces on Windows); the
            // catch below turns those into a file error too.
            Path file = LongPath.of(raw);
            if (!Files.exists(file))
                throw new SchemeError(pos, new FileErrorObject("delete-file: file does not exist: " + raw, new Object[] { Value.asString(arguments[0]) }));
            Files.delete(file);
            return new Values();
        } catch (SchemeError e) { throw e; }
        catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("delete-file: " + e.getMessage(), new Object[] { Value.asString(arguments[0]) }));
        }
    }
}
