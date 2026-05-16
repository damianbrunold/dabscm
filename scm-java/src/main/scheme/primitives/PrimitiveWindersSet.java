package scheme.primitives;
import scheme.*;

public class PrimitiveWindersSet extends Primitive {
    @Override public String name() { return "%winders-set!"; }
    @Override public String info() {
        return "Syntax: (%winders-set! winders)\n" +
               "Library: (scm core)\n" +
               "Description: Sets the current VM's winder chain to the given list. Used internally by dynamic-wind to save and restore the winder state.\n" +
               "Example:\n" +
               "  (%winders-set! '())";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        VM vm = VM.current.get();
        if (vm != null) vm.winders = args[0];
        return Value.NIL;
    }
}
