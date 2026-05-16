package scheme.primitives;

import scheme.*;

public class PrimitiveSpecialFolderApplicationData extends Primitive {
    @Override
    public String name() {
        return "special-folder-application-data";
    }

    @Override
    public String info() {
        return "Syntax: (special-folder-application-data)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the path of the user's application data directory as a string.\n" +
               "Example:\n" +
               "  (special-folder-application-data) => \"/home/user/.config\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        String appdata = System.getenv("APPDATA");
        if (appdata != null) return appdata.toCharArray();
        String xdg = System.getenv("XDG_CONFIG_HOME");
        if (xdg != null) return xdg.toCharArray();
        return (System.getProperty("user.home") + "/.config").toCharArray();
    }
}
