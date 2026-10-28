package scheme.primitives;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import scheme.*;

public class PrimitiveSHA256File extends Primitive {
    @Override
    public String name() { return "sha256-file"; }

    @Override
    public String info() {
        return "Syntax: (sha256-file path)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the SHA-256 hash of the contents of the file at path as a bytevector. The file\n" +
               "  is read in pieces, so it may be larger than memory.\n" +
               "Example:\n" +
               "  (bytevector->hex (sha256-file \"upload.bin\")) => \"9f86d0...\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String path = new String(Value.asString(arguments[0]));
        try (InputStream in = Files.newInputStream(Paths.get(path))) {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buf = new byte[65536];
            int r;
            while ((r = in.read(buf)) > 0) digest.update(buf, 0, r);
            return digest.digest();
        } catch (NoSuchAlgorithmException e) {
            throw new SchemeError(pos, "sha256-file: algorithm not available");
        } catch (IOException e) {
            throw new SchemeError(pos, "sha256-file: ~a", e.getMessage());
        }
    }
}
