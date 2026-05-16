package scheme.primitives;

import scheme.*;

public class PrimitiveSysOsVersion extends Primitive {
    @Override
    public String name() {
        return "sys-os-version";
    }

    @Override
    public String info() {
        return "Syntax: (sys-os-version)\n" +
               "Library: (scm system)\n" +
               "Description: Returns a list describing the operating system: (platform version-string major minor service-pack).\n" +
               "Example:\n" +
               "  (sys-os-version) => (linux \"Unix 5.15.0.0\" 5 15 \"\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        var list = new Object[] {
            Value.intern(getOsName()),
            getOsVersion().toCharArray()
        };
        return Pair.list(list);
    }

    private String getOsName() {
        String name = System.getProperty("os.name").toLowerCase();
        if (name.contains("windows")) return "windows";
        if (name.contains("linux")) return "linux";
        return "unknown";
    }

    private String getOsVersion() {
        return System.getProperty("os.version");
    }

}
