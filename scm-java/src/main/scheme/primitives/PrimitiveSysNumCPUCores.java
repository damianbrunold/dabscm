package scheme.primitives;

import scheme.*;

public class PrimitiveSysNumCPUCores extends Primitive {
    @Override
    public String name() {
        return "sys-num-cpu-cores";
    }

    @Override
    public String info() {
        return "Syntax: (sys-num-cpu-cores)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the number of logical CPU cores available to the current process as an integer.\n" +
               "Example:\n" +
               "  (sys-num-cpu-cores) => 8";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return (long) Runtime.getRuntime().availableProcessors();
    }
}
