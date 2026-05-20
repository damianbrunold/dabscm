namespace schemerepl;

public enum KeyType
{
    Char,
    Enter, Backspace, Delete, Tab,
    Left, Right, Up, Down,
    Home, End, PageUp, PageDown,
    Esc, EOF, Interrupt,
    Unknown
}

public sealed class Key
{
    public KeyType Type { get; }
    public int Ch { get; }
    public bool Ctrl { get; }
    public bool Alt { get; }
    public bool Shift { get; }

    private Key(KeyType t, int ch, bool ctrl, bool alt, bool shift)
    {
        Type = t; Ch = ch; Ctrl = ctrl; Alt = alt; Shift = shift;
    }

    public static Key Chr(int c) => new(KeyType.Char, c, false, false, false);
    public static Key CtrlChr(int c) => new(KeyType.Char, c, true, false, false);
    public static Key AltChr(int c) => new(KeyType.Char, c, false, true, false);
    public static Key Named(KeyType t) => new(t, 0, false, false, false);
    public static Key Named(KeyType t, bool ctrl, bool shift = false) => new(t, 0, ctrl, false, shift);
}
