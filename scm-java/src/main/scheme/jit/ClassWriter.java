package scheme.jit;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

// A minimal class file writer for the JIT: one class with static fields,
// a static initializer and methods, as class file version 55 (Java 11).
// The StackMapTable gives each branch target and exception handler a full
// frame: the method's locals have one type throughout (Code.locals), the
// stack is empty unless set for the label (Code.stackAt).
final class ClassWriter {

    static final int ACC_PUBLIC = 0x0001, ACC_PRIVATE = 0x0002, ACC_STATIC = 0x0008,
                     ACC_FINAL = 0x0010, ACC_SUPER = 0x0020;

    private final ByteArrayOutputStream poolBytes = new ByteArrayOutputStream();
    private final DataOutputStream pool = new DataOutputStream(poolBytes);
    private final HashMap<String, Integer> poolIndex = new HashMap<>();
    private int poolCount = 1;

    private final String name;
    private final String superName;
    private final List<byte[]> fields = new ArrayList<>();
    private final List<byte[]> methods = new ArrayList<>();

    ClassWriter(String name, String superName) {
        this.name = name;
        this.superName = superName;
    }

    // ---- constant pool ----

    private int entry(String key, int size, PoolWriter w) {
        Integer i = poolIndex.get(key);
        if (i != null) return i;
        try { w.write(pool); } catch (IOException e) { throw new IllegalStateException(e); }
        int index = poolCount;
        poolCount += size;
        poolIndex.put(key, index);
        return index;
    }

    private interface PoolWriter { void write(DataOutputStream out) throws IOException; }

    int utf8(String s) {
        return entry("U" + s, 1, out -> { out.writeByte(1); out.writeUTF(s); });
    }

    int classRef(String internalName) {
        int n = utf8(internalName);
        return entry("C" + internalName, 1, out -> { out.writeByte(7); out.writeShort(n); });
    }

    int string(String s) {
        int n = utf8(s);
        return entry("S" + s, 1, out -> { out.writeByte(8); out.writeShort(n); });
    }

    int integer(int v) {
        return entry("I" + v, 1, out -> { out.writeByte(3); out.writeInt(v); });
    }

    int longConst(long v) {
        return entry("J" + v, 2, out -> { out.writeByte(5); out.writeLong(v); });
    }

    private int nameAndType(String n, String desc) {
        int a = utf8(n), b = utf8(desc);
        return entry("N" + n + ":" + desc, 1, out -> { out.writeByte(12); out.writeShort(a); out.writeShort(b); });
    }

    int fieldRef(String owner, String n, String desc) {
        int c = classRef(owner), nt = nameAndType(n, desc);
        return entry("F" + owner + "." + n + ":" + desc, 1, out -> { out.writeByte(9); out.writeShort(c); out.writeShort(nt); });
    }

    int methodRef(String owner, String n, String desc) {
        int c = classRef(owner), nt = nameAndType(n, desc);
        return entry("M" + owner + "." + n + ":" + desc, 1, out -> { out.writeByte(10); out.writeShort(c); out.writeShort(nt); });
    }

    // ---- members ----

    void field(int access, String n, String desc) {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(b);
        try {
            out.writeShort(access);
            out.writeShort(utf8(n));
            out.writeShort(utf8(desc));
            out.writeShort(0);
        } catch (IOException e) { throw new IllegalStateException(e); }
        fields.add(b.toByteArray());
    }

    void method(int access, String n, String desc, Code code) {
        byte[] bytes = code.bytes();
        if (bytes.length > 65535) throw new IllegalStateException("method too large");
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(b);
        try {
            out.writeShort(access);
            out.writeShort(utf8(n));
            out.writeShort(utf8(desc));
            out.writeShort(1);
            out.writeShort(utf8("Code"));
            int handlers = code.handlers.size();
            byte[] frames = code.stackMapTable();
            int attrs = (frames == null ? 0 : 6 + frames.length)
                      + (code.lines.isEmpty() ? 0 : 6 + 2 + code.lines.size() * 2);
            out.writeInt(2 + 2 + 4 + bytes.length + 2 + handlers * 8 + 2 + attrs);
            out.writeShort(code.maxStack);
            out.writeShort(code.maxLocals);
            out.writeInt(bytes.length);
            out.write(bytes);
            out.writeShort(handlers);
            for (int[] h : code.handlers) {
                out.writeShort(code.labelPos(h[0]));
                out.writeShort(code.labelPos(h[1]));
                out.writeShort(code.labelPos(h[2]));
                out.writeShort(h[3]);
            }
            out.writeShort((frames == null ? 0 : 1) + (code.lines.isEmpty() ? 0 : 1));
            if (frames != null) {
                out.writeShort(utf8("StackMapTable"));
                out.writeInt(frames.length);
                out.write(frames);
            }
            if (!code.lines.isEmpty()) {
                out.writeShort(utf8("LineNumberTable"));
                out.writeInt(2 + code.lines.size() * 2);
                out.writeShort(code.lines.size() / 2);
                for (int v : code.lines) out.writeShort(v);
            }
        } catch (IOException e) { throw new IllegalStateException(e); }
        methods.add(b.toByteArray());
    }

    byte[] toBytes() {
        int thisIndex = classRef(name), superIndex = classRef(superName);
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(b);
        try {
            out.writeInt(0xCAFEBABE);
            out.writeShort(0);
            out.writeShort(55);
            pool.flush();
            out.writeShort(poolCount);
            out.write(poolBytes.toByteArray());
            out.writeShort(ACC_PUBLIC | ACC_FINAL | ACC_SUPER);
            out.writeShort(thisIndex);
            out.writeShort(superIndex);
            out.writeShort(0);
            out.writeShort(fields.size());
            for (byte[] f : fields) out.write(f);
            out.writeShort(methods.size());
            for (byte[] m : methods) out.write(m);
            out.writeShort(0);
        } catch (IOException e) { throw new IllegalStateException(e); }
        return b.toByteArray();
    }

    // ---- code ----

    static final int NOP = 0, ACONST_NULL = 1, ICONST_0 = 3, ICONST_1 = 4, BIPUSH = 16, SIPUSH = 17,
        LDC_W = 19, LDC2_W = 20, ILOAD = 21, ALOAD = 25, ISTORE = 54, ASTORE = 58,
        AALOAD = 50, AASTORE = 83, POP = 87, DUP = 89, SWAP = 95, IADD = 96, ISUB = 100,
        IFEQ = 153, IFNE = 154, IF_ICMPEQ = 159, IF_ICMPNE = 160, IF_ICMPGE = 162,
        IF_ACMPEQ = 165, IF_ACMPNE = 166, GOTO_W = 200, GOTO = 167, ARETURN = 176, RETURN = 177,
        GETSTATIC = 178, PUTSTATIC = 179, GETFIELD = 180, PUTFIELD = 181,
        INVOKEVIRTUAL = 182, INVOKESPECIAL = 183, INVOKESTATIC = 184,
        NEW = 187, ANEWARRAY = 189, ARRAYLENGTH = 190, ATHROW = 191, CHECKCAST = 192,
        INSTANCEOF = 193, IFNULL = 198, IFNONNULL = 199;

    // Method code with labels. Branches are emitted as goto_w-sized
    // placeholders where needed: all branch offsets are 16 bits, which
    // ClassWriter.method rejects beyond 64K anyway.
    final class Code {
        private byte[] buf = new byte[256];
        private int len;
        private final ArrayList<Integer> labels = new ArrayList<>();
        private final ArrayList<int[]> fixups = new ArrayList<>(); // {pos of opcode, pos of offset, label}
        final ArrayList<int[]> handlers = new ArrayList<>();       // {startLabel, endLabel, handlerLabel, catchType}
        int maxStack = 8;
        int maxLocals;
        // the verification type of each local: "I" or an internal class name
        String[] locals;
        private final HashMap<Integer, String[]> stacks = new HashMap<>();
        private final java.util.TreeSet<Integer> frameLabels = new java.util.TreeSet<>();

        // pc, line pairs (the line of generated code: the instruction index)
        final ArrayList<Integer> lines = new ArrayList<>();

        void line(int line) { lines.add(len); lines.add(line); }

        // the stack types at label (when not empty)
        void stackAt(int label, String... types) { stacks.put(label, types); }

        int size() { return len; }

        private void u1(int v) {
            if (len == buf.length) buf = java.util.Arrays.copyOf(buf, buf.length * 2);
            buf[len++] = (byte) v;
        }

        private void u2(int v) { u1(v >> 8); u1(v); }

        int newLabel() { labels.add(-1); return labels.size() - 1; }

        void mark(int label) { labels.set(label, len); }

        int labelPos(int label) {
            int p = labels.get(label);
            if (p < 0) throw new IllegalStateException("unmarked label");
            return p;
        }

        void op(int opcode) { u1(opcode); }

        void iconst(int v) {
            if (v >= -1 && v <= 5) u1(ICONST_0 + v);
            else if (v >= -128 && v <= 127) { u1(BIPUSH); u1(v); }
            else if (v >= -32768 && v <= 32767) { u1(SIPUSH); u2(v); }
            else { u1(LDC_W); u2(integer(v)); }
        }

        void lconst(long v) { u1(LDC2_W); u2(longConst(v)); }

        void ldcString(String s) { u1(LDC_W); u2(string(s)); }

        private void local(int opcode, int index) {
            if (index > 255) { u1(196); u1(opcode); u2(index); }
            else { u1(opcode); u1(index); }
            if (index + 1 > maxLocals) maxLocals = index + 1;
        }

        void aload(int i) { local(ALOAD, i); }
        void astore(int i) { local(ASTORE, i); }
        void iload(int i) { local(ILOAD, i); }
        void istore(int i) { local(ISTORE, i); }

        void jump(int opcode, int label) {
            int at = len;
            u1(opcode);
            fixups.add(new int[] { at, len, label });
            frameLabels.add(label);
            u2(0);
        }

        void type(int opcode, String internalName) { u1(opcode); u2(classRef(internalName)); }

        void field(int opcode, String owner, String n, String desc) { u1(opcode); u2(fieldRef(owner, n, desc)); }

        void invoke(int opcode, String owner, String n, String desc) { u1(opcode); u2(methodRef(owner, n, desc)); }

        void handler(int start, int end, int handler, String catchType) {
            handlers.add(new int[] { start, end, handler, catchType == null ? 0 : classRef(catchType) });
            frameLabels.add(handler);
        }

        private void typeInfo(DataOutputStream out, String t) throws IOException {
            if (t.equals("I")) out.writeByte(1);
            else { out.writeByte(7); out.writeShort(classRef(t)); }
        }

        byte[] stackMapTable() {
            if (frameLabels.isEmpty()) return null;
            java.util.TreeMap<Integer, String[]> byPos = new java.util.TreeMap<>();
            for (int label : frameLabels) {
                String[] stack = stacks.getOrDefault(label, new String[0]);
                String[] old = byPos.put(labelPos(label), stack);
                if (old != null && !java.util.Arrays.equals(old, stack))
                    throw new IllegalStateException("conflicting frames");
            }
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(b);
            try {
                out.writeShort(byPos.size());
                int prev = -1;
                for (java.util.Map.Entry<Integer, String[]> e : byPos.entrySet()) {
                    out.writeByte(255);
                    out.writeShort(e.getKey() - prev - 1);
                    prev = e.getKey();
                    out.writeShort(locals.length);
                    for (String t : locals) typeInfo(out, t);
                    out.writeShort(e.getValue().length);
                    for (String t : e.getValue()) typeInfo(out, t);
                }
            } catch (IOException e) { throw new IllegalStateException(e); }
            return b.toByteArray();
        }

        byte[] bytes() {
            for (int[] f : fixups) {
                int offset = labelPos(f[2]) - f[0];
                if (offset < -32768 || offset > 32767) throw new IllegalStateException("branch too far");
                buf[f[1]] = (byte) (offset >> 8);
                buf[f[1] + 1] = (byte) offset;
            }
            return java.util.Arrays.copyOf(buf, len);
        }
    }

    Code code() { return new Code(); }
}
