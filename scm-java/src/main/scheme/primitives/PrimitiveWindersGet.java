package scheme.primitives;
import scheme.*;

public class PrimitiveWindersGet extends Primitive {
    @Override public String name() { return "%winders-get"; }
    @Override public String info() {
        return "Syntax: (%winders-get)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the current winder chain list used by dynamic-wind to track before/after thunks.\n" +
               "Example:\n" +
               "  (%winders-get) => ()";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 0, 0);
        VM vm = VM.current.get();
        return vm != null ? vm.winders : Value.NIL;
    }
}
