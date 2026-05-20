namespace schemerepl;

/// <summary>
/// Translates Console.ReadKey output into the editor's Key abstraction.
/// Console.ReadKey already parses CSI sequences cross-platform, so this
/// is mostly a small lookup table.
/// </summary>
public sealed class KeyReader
{
    private readonly Terminal term;
    public KeyReader(Terminal t) { term = t; }

    public Key Next()
    {
        var k = term.ReadKey();
        bool ctrl = (k.Modifiers & ConsoleModifiers.Control) != 0;
        bool alt = (k.Modifiers & ConsoleModifiers.Alt) != 0;
        bool shift = (k.Modifiers & ConsoleModifiers.Shift) != 0;

        switch (k.Key)
        {
            case ConsoleKey.Enter:      return Key.Named(KeyType.Enter);
            case ConsoleKey.Tab:        return Key.Named(KeyType.Tab);
            case ConsoleKey.Backspace:  return Key.Named(KeyType.Backspace);
            case ConsoleKey.Delete:     return Key.Named(KeyType.Delete, ctrl, shift);
            case ConsoleKey.LeftArrow:  return Key.Named(KeyType.Left, ctrl, shift);
            case ConsoleKey.RightArrow: return Key.Named(KeyType.Right, ctrl, shift);
            case ConsoleKey.UpArrow:    return Key.Named(KeyType.Up, ctrl, shift);
            case ConsoleKey.DownArrow:  return Key.Named(KeyType.Down, ctrl, shift);
            case ConsoleKey.Home:       return Key.Named(KeyType.Home, ctrl, shift);
            case ConsoleKey.End:        return Key.Named(KeyType.End, ctrl, shift);
            case ConsoleKey.PageUp:     return Key.Named(KeyType.PageUp);
            case ConsoleKey.PageDown:   return Key.Named(KeyType.PageDown);
            case ConsoleKey.Escape:     return Key.Named(KeyType.Esc);
        }

        char c = k.KeyChar;
        if (c == '\0')
        {
            return Key.Named(KeyType.Unknown);
        }
        if (ctrl && !alt)
        {
            if (c == 3) return Key.Named(KeyType.Interrupt);
            if (c == 4) return Key.Named(KeyType.EOF);
            if (c < 0x20) return Key.CtrlChr(c + 64);
            // Some terminals deliver Ctrl+letter as 'a'..'z' with the Control modifier set.
            if (c >= 'a' && c <= 'z') return Key.CtrlChr(c - 32);
            if (c >= 'A' && c <= 'Z') return Key.CtrlChr(c);
        }
        if (alt && !ctrl)
        {
            return Key.AltChr(c);
        }
        return Key.Chr(c);
    }
}
