package scheme.repl;

/**
 * A single decoded key event from the terminal. Either a printable
 * character (`type == CHAR`, `ch` carries it) or one of a small set of
 * named keys. Modifier flags `ctrl` / `alt` apply to both forms.
 */
public final class Key {
    public enum Type {
        CHAR,
        ENTER, BACKSPACE, DELETE, TAB,
        LEFT, RIGHT, UP, DOWN,
        HOME, END, PAGE_UP, PAGE_DOWN,
        ESC, EOF, INTERRUPT,
        UNKNOWN
    }

    public final Type type;
    public final int ch;
    public final boolean ctrl;
    public final boolean alt;
    public final boolean shift;

    private Key(Type type, int ch, boolean ctrl, boolean alt, boolean shift) {
        this.type = type;
        this.ch = ch;
        this.ctrl = ctrl;
        this.alt = alt;
        this.shift = shift;
    }

    public static Key chr(int c) { return new Key(Type.CHAR, c, false, false, false); }
    public static Key ctrlChr(int c) { return new Key(Type.CHAR, c, true, false, false); }
    public static Key altChr(int c) { return new Key(Type.CHAR, c, false, true, false); }
    public static Key named(Type t) { return new Key(t, 0, false, false, false); }
    public static Key named(Type t, boolean ctrl) { return new Key(t, 0, ctrl, false, false); }
    public static Key named(Type t, boolean ctrl, boolean shift) { return new Key(t, 0, ctrl, false, shift); }

    public boolean isPrintable() {
        return type == Type.CHAR && !ctrl && !alt && ch >= 0x20 && ch != 0x7f;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        if (ctrl) sb.append("C-");
        if (alt) sb.append("M-");
        if (shift) sb.append("S-");
        if (type == Type.CHAR) {
            if (ch < 0x20) sb.append("^").append((char)(ch + 64));
            else sb.append((char) ch);
        } else {
            sb.append(type.name());
        }
        return sb.toString();
    }
}
