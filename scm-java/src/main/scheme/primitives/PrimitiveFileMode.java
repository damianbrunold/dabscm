package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermission;
import java.util.EnumSet;
import java.util.Set;
import scheme.*;

/** file-mode, set-file-mode! and real-path ((scm fs)). */
public class PrimitiveFileMode extends Primitive {
    private final String name;

    public PrimitiveFileMode(String name) {
        this.name = name;
    }

    @Override
    public String name() { return name; }

    @Override
    public String info() {
        switch (name) {
            case "file-mode":
                return "Syntax: (file-mode path)\n" +
                       "Library: (scm fs)\n" +
                       "Description: Returns the permission bits of path as an integer (as chmod\n" +
                       "  takes them), or #f on Windows or if path does not exist.\n" +
                       "Example:\n" +
                       "  (number->string (file-mode \"script.sh\") 8) => \"755\"";
            case "set-file-mode!":
                return "Syntax: (set-file-mode! path mode)\n" +
                       "Library: (scm fs)\n" +
                       "Description: Sets the permission bits of path to the integer mode, in the\n" +
                       "  process (no chmod program). Returns #t, or #f on Windows or failure.\n" +
                       "Example:\n" +
                       "  (set-file-mode! \"script.sh\" #o755) => #t";
            default:
                return "Syntax: (real-path path)\n" +
                       "Library: (scm fs)\n" +
                       "Description: Returns path made absolute with . and .. and symbolic links\n" +
                       "  resolved, or #f if path does not exist.\n" +
                       "Example:\n" +
                       "  (real-path \"link/../file.txt\") => \"/home/me/file.txt\"";
        }
    }

    private static final PosixFilePermission[] BITS = {
        PosixFilePermission.OTHERS_EXECUTE, PosixFilePermission.OTHERS_WRITE, PosixFilePermission.OTHERS_READ,
        PosixFilePermission.GROUP_EXECUTE, PosixFilePermission.GROUP_WRITE, PosixFilePermission.GROUP_READ,
        PosixFilePermission.OWNER_EXECUTE, PosixFilePermission.OWNER_WRITE, PosixFilePermission.OWNER_READ,
    };

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (name.equals("set-file-mode!")) checkArgs(pos, arguments, 2, 2);
        else checkArgs(pos, arguments, 1, 1);
        Path path = SchemePaths.path(new String(Value.asString(arguments[0])));
        try {
            switch (name) {
                case "file-mode": {
                    if (!Files.exists(path)) return Value.F;
                    Set<PosixFilePermission> perms = Files.getPosixFilePermissions(path);
                    long mode = 0;
                    for (int i = 0; i < BITS.length; i++) if (perms.contains(BITS[i])) mode |= 1L << i;
                    return mode;
                }
                case "set-file-mode!": {
                    long mode = IntegerMath.toLong(arguments[1]);
                    if (mode < 0 || mode > 07777) throw new SchemeError(pos, "set-file-mode!: wrong argument type");
                    Set<PosixFilePermission> perms = EnumSet.noneOf(PosixFilePermission.class);
                    for (int i = 0; i < BITS.length; i++) if ((mode & (1L << i)) != 0) perms.add(BITS[i]);
                    Files.setPosixFilePermissions(path, perms);
                    return Value.T;
                }
                default:
                    if (!Files.exists(path)) return Value.F;
                    return path.toRealPath().toString().toCharArray();
            }
        } catch (SchemeError e) {
            throw e;
        } catch (UnsupportedOperationException | java.io.IOException | SecurityException e) {
            return Value.F;
        }
    }
}
