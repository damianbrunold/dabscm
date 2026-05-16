package scheme;

public class PrimitiveCurrentSourceLocation extends Primitive {
    @Override public String name() { return "current-source-location"; }

    @Override public String info() {
        return "Syntax: (current-source-location)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the source position of the call site as (filename line column), or #f if no position is available.\n" +
               "Example:\n" +
               "  (current-source-location) => (\"file.scm\" 42 0)";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        if (pos != null)
            return pos.toSexpr();
        return Value.F;
    }
}
