package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileWriteB extends Primitive {
    @Override public String name() { return "random-access-file-write!"; }
    @Override public String info() {
        return "Syntax: (random-access-file-write! f offset bv [start [end]])\n" +
               "Library: (scm random access)\n" +
               "Description: Writes the bytes bv[start..end) to random-access file f starting at byte offset, extending the file when the write goes past the current end. start defaults to 0 and end to the length of bv. Returns the number of bytes written.\n" +
               "Example:\n" +
               "  (random-access-file-write! f 0 #u8(1 2 3)) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 5);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        long offset = IntegerMath.toLong(arguments[1]);
        byte[] bv = Value.asBytevector(arguments[2]);
        int start = arguments.length > 3 ? IntegerMath.toInt(arguments[3]) : 0;
        int end = arguments.length > 4 ? IntegerMath.toInt(arguments[4]) : bv.length;
        if (offset < 0) throw new SchemeError(pos, name() + ": negative offset, ~s", offset);
        if (start < 0 || end > bv.length || start > end)
            throw new SchemeError(pos, name() + ": bad start/end (~s ~s) for bytevector of length ~s", start, end, bv.length);
        try {
            return (long) f.write(offset, bv, start, end);
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
