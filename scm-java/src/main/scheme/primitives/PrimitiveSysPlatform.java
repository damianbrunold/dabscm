package scheme.primitives;

import scheme.*;

public class PrimitiveSysPlatform extends Primitive {
    @Override
    public String name() {
        return "sys-platform";
    }

    @Override
    public String info() {
        return "Syntax: (sys-platform)\n" +
               "Library: (scm system)\n" +
               "Description: Returns a symbol identifying the current operating system platform: windows, linux, or unknown.\n" +
               "Example:\n" +
               "  (sys-platform) => linux";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return Value.intern(getOsName());
    }

    private String getOsName() {
        String name = System.getProperty("os.name").toLowerCase();
        if (name.contains("windows")) return "windows";
        if (name.contains("linux")) return "linux";
        return "unknown";
    }

}
