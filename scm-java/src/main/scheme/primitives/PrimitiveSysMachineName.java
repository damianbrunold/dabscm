package scheme.primitives;

import java.net.InetAddress;

import scheme.*;

public class PrimitiveSysMachineName extends Primitive {
    @Override
    public String name() {
        return "sys-machine-name";
    }

    @Override
    public String info() {
        return "Syntax: (sys-machine-name)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the hostname of the current machine as a string.\n" +
               "Example:\n" +
               "  (sys-machine-name) => \"myhost\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        try {
            var addr = InetAddress.getLocalHost();
            if (addr != null) {
                var hostname = addr.getHostName();
                if (hostname != null) {
                    return hostname.toCharArray();
                }
            }
            return Value.F;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
