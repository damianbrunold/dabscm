package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveSpecialFolderDocuments extends Primitive {
    @Override
    public String name() {
        return "special-folder-documents";
    }

    @Override
    public String info() {
        return "Syntax: (special-folder-documents)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the path of the user's documents directory as a string.\n" +
               "Example:\n" +
               "  (special-folder-documents) => \"/home/user/Documents\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        String userProfile = System.getenv("USERPROFILE");
        if (userProfile != null) return (userProfile + File.separator + "Documents").toCharArray();
        String xdg = System.getenv("XDG_DOCUMENTS_DIR");
        if (xdg != null) return xdg.toCharArray();
        return System.getProperty("user.home").toCharArray();
    }
}
