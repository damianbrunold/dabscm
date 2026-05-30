package scheme.primitives;

import scheme.*;

import java.io.RandomAccessFile;
import java.nio.file.Files;

public class PrimitiveOpenRandomAccessFile extends Primitive {
    @Override public String name() { return "open-random-access-file"; }
    @Override public String info() {
        return "Syntax: (open-random-access-file filename mode)\n" +
               "Library: (scm random access)\n" +
               "Description: Opens filename for positioned (random-access) binary I/O and returns a random-access file handle. mode is a symbol or string: read opens an existing file read-only; write creates or truncates the file for read/write; update opens (creating if absent) for read/write without truncating. Raises a file-error on failure.\n" +
               "Example:\n" +
               "  (let ((f (open-random-access-file \"data.store\" 'write)))\n" +
               "    (random-access-file-write! f 0 #u8(1 2 3))\n" +
               "    (close-random-access-file f))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        String filename = new String(Value.asString(arguments[0]));
        String mode = Value.isSymbol(arguments[1])
                ? Value.asSymbol(arguments[1])
                : new String(Value.asString(arguments[1]));

        boolean truncate = false;
        String javaMode;
        switch (mode) {
            case "read":
                if (!Files.exists(LongPath.of(filename)))
                    throw new SchemeError(pos, new FileErrorObject("open-random-access-file: file not found", new Object[] { filename }));
                javaMode = "r";
                break;
            case "write":
                javaMode = "rw";
                truncate = true;
                break;
            case "update":
                javaMode = "rw";
                break;
            default:
                throw new SchemeError(pos, "open-random-access-file: bad mode, ~s (expected read, write, or update)", mode);
        }

        try {
            RandomAccessFile raf = new RandomAccessFile(LongPath.of(filename).toFile(), javaMode);
            if (truncate) raf.setLength(0);
            return new NativeValue(new RandomAccessFileHandle(raf, filename));
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-random-access-file: io error", new Object[] { filename }));
        }
    }
}
