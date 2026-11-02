package scheme.primitives;

import scheme.*;

public class PrimitiveReadData extends Primitive {

    public static final int DEFAULT_MAX_DEPTH = 1000;

    private final PrimitiveRead reader;

    public PrimitiveReadData(Modules modules) {
        this.reader = new PrimitiveRead(modules);
    }

    @Override
    public String name() {
        return "read-data";
    }

    @Override
    public String info() {
        return "Syntax: (read-data port [max-depth])\n" +
               "Library: (scm io)\n" +
               "Description: Like read, for data from an untrusted source (uploads,\n" +
               "  pasted text, network). Datum labels (#0= and #0#) are rejected, so\n" +
               "  the result never shares structure or contains cycles, and lists,\n" +
               "  vectors and quote forms may nest at most max-depth levels (default\n" +
               "  1000). Either violation raises a read error (read-error? is true)\n" +
               "  instead of building a cyclic datum or exhausting the stack. Returns\n" +
               "  an end-of-file object at the end of the input.\n" +
               "Example:\n" +
               "  (read-data (open-input-string \"(a (b c))\")) => (a (b c))\n" +
               "  (read-data (open-input-string \"#0=(a . #0#)\")) => read error\n" +
               "  (read-data (open-input-string \"((x))\") 1) => read error";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        TextStream port = Value.asInputPort(arguments[0]);
        int maxDepth = DEFAULT_MAX_DEPTH;
        if (arguments.length > 1) {
            long d = IntegerMath.toLong(arguments[1]);
            if (d < 1) throw new SchemeError(pos, "read-data: max-depth must be positive");
            maxDepth = (int) Math.min(d, 100000);
        }
        try {
            return reader.readData(port, maxDepth);
        } catch (SchemeError e) {
            if (e.errorObject != null) throw e;
            throw new SchemeError(pos, new ReadErrorObject("read-data: " + e.getMessage(), new Object[0]));
        } catch (StackOverflowError e) {
            throw new SchemeError(pos, new ReadErrorObject("read-data: nesting too deep", new Object[0]));
        } catch (Exception e) {
            throw new SchemeError(pos, new ReadErrorObject("read-data: io failure: " + e.getMessage(), new Object[0]));
        }
    }
}
