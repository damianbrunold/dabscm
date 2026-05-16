package scheme;

public class PrimitivePairSource extends Primitive {
    @Override public String name() { return "%pair-source"; }

    @Override public String info() {
        return "Syntax: (%pair-source pair)\n" +
               "Library: (scm core)\n" +
               "Description: Returns the source position of a pair as (filename . line), or #f if no position is available.";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isPair(arguments[0])) {
            SourcePos p = Value.asPair(arguments[0]).pos;
            if (p != null)
                return new Pair(p.filename.toCharArray(), p.line);
        }
        return Value.F;
    }
}
