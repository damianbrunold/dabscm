package scheme.primitives;

import scheme.*;
import java.io.InputStream;

public class PrimitiveSysScmVersion extends Primitive {
    @Override public String name() { return "sys-scm-version"; }

    @Override public String info() {
        return "Syntax: (sys-scm-version)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the SCM interpreter version as a string.\n" +
               "Example:\n" +
               "  (sys-scm-version) => \"0.0.1\"";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        String version = "unknown";
        try (InputStream is = getClass().getResourceAsStream("/version.txt")) {
            if (is != null) {
                version = new String(is.readAllBytes()).trim();
            }
        } catch (Exception e) {}
        return version.toCharArray();
    }
}
