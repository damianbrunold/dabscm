package scheme.repl;

import java.io.IOException;

/**
 * Translates a byte stream from a raw terminal into {@link Key} events.
 *
 * Handles xterm-style CSI escape sequences (ESC '['), the few VT220
 * variants ('ESC O'), and the common Linux/macOS console quirks. Unknown
 * sequences are returned as {@link Key.Type#UNKNOWN}.
 *
 * UTF-8 multi-byte sequences are decoded so that the resulting
 * {@link Key#ch} is a Unicode code point.
 */
public final class KeyReader {

    private final Terminal term;

    public KeyReader(Terminal term) {
        this.term = term;
    }

    public Key next() throws IOException {
        int b = term.readByte();
        if (b < 0) return Key.named(Key.Type.EOF);

        switch (b) {
            case 0x0d: case 0x0a: return Key.named(Key.Type.ENTER);
            case 0x09:            return Key.named(Key.Type.TAB);
            case 0x7f: case 0x08: return Key.named(Key.Type.BACKSPACE);
            case 0x03:            return Key.named(Key.Type.INTERRUPT);
            case 0x04:            return Key.named(Key.Type.EOF);
            case 0x1b:            return parseEscape();
            default:
                if (b < 0x20) return Key.ctrlChr(b + 64); // Ctrl+A..Z -> 'A'..'Z'
                return readUtf8FirstByte(b);
        }
    }

    private Key readUtf8FirstByte(int b0) throws IOException {
        if ((b0 & 0x80) == 0) return Key.chr(b0);
        int needed;
        int code;
        if      ((b0 & 0xe0) == 0xc0) { needed = 1; code = b0 & 0x1f; }
        else if ((b0 & 0xf0) == 0xe0) { needed = 2; code = b0 & 0x0f; }
        else if ((b0 & 0xf8) == 0xf0) { needed = 3; code = b0 & 0x07; }
        else return Key.chr(b0); // malformed; treat as latin-1
        for (int i = 0; i < needed; i++) {
            int b = term.readByte();
            if (b < 0) return Key.named(Key.Type.EOF);
            code = (code << 6) | (b & 0x3f);
        }
        return Key.chr(code);
    }

    /** Parses a sequence beginning at ESC. The ESC byte has already been consumed. */
    private Key parseEscape() throws IOException {
        // ESC alone vs ESC <something>: peek with a short window
        int b = term.peekByteIfAny();
        if (b < 0) return Key.named(Key.Type.ESC);

        // Consume the byte we peeked
        b = term.readByte();
        if (b == '[' ) return parseCsi();
        if (b == 'O') return parseSs3();
        if (b == 0x1b) return Key.named(Key.Type.ESC); // ESC ESC -> ESC

        // ESC <printable> -> Alt+<char>
        if (b >= 0x20) {
            if (b < 0x80) return Key.altChr(b);
            // Multi-byte Alt is rare; emit Alt+first byte and let the rest be processed next time
            return Key.altChr(b);
        }
        return Key.named(Key.Type.UNKNOWN);
    }

    /** Parse a CSI sequence: ESC [ <params> <final>. */
    private Key parseCsi() throws IOException {
        StringBuilder params = new StringBuilder();
        int b;
        while (true) {
            b = term.readByte();
            if (b < 0) return Key.named(Key.Type.EOF);
            if ((b >= '0' && b <= '9') || b == ';' || b == '?' ) {
                params.append((char) b);
            } else {
                break;
            }
        }
        // b is the final byte
        String p = params.toString();
        int mod = 0; // 1=none, 2=Shift, 3=Alt, 4=Shift+Alt, 5=Ctrl, 6=Ctrl+Shift, 7=Ctrl+Alt
        int n1 = -1;
        if (!p.isEmpty()) {
            String[] parts = p.split(";");
            try { n1 = Integer.parseInt(parts[0]); } catch (Exception ignored) {}
            if (parts.length >= 2) try { mod = Integer.parseInt(parts[1]); } catch (Exception ignored) {}
        }
        boolean ctrl = mod == 5 || mod == 6 || mod == 7;
        boolean shift = mod == 2 || mod == 4 || mod == 6;
        switch (b) {
            case 'A': return Key.named(Key.Type.UP, ctrl, shift);
            case 'B': return Key.named(Key.Type.DOWN, ctrl, shift);
            case 'C': return Key.named(Key.Type.RIGHT, ctrl, shift);
            case 'D': return Key.named(Key.Type.LEFT, ctrl, shift);
            case 'H': return Key.named(Key.Type.HOME, ctrl, shift);
            case 'F': return Key.named(Key.Type.END, ctrl, shift);
            case '~':
                switch (n1) {
                    case 1: case 7: return Key.named(Key.Type.HOME, ctrl, shift);
                    case 4: case 8: return Key.named(Key.Type.END, ctrl, shift);
                    case 2: return Key.named(Key.Type.UNKNOWN); // Insert
                    case 3: return Key.named(Key.Type.DELETE, ctrl, shift);
                    case 5: return Key.named(Key.Type.PAGE_UP, ctrl, shift);
                    case 6: return Key.named(Key.Type.PAGE_DOWN, ctrl, shift);
                    default: return Key.named(Key.Type.UNKNOWN);
                }
            default:
                return Key.named(Key.Type.UNKNOWN);
        }
    }

    /** Parse an SS3 sequence: ESC O <final>. Used by VT100 for some arrows / F-keys. */
    private Key parseSs3() throws IOException {
        int b = term.readByte();
        switch (b) {
            case 'A': return Key.named(Key.Type.UP);
            case 'B': return Key.named(Key.Type.DOWN);
            case 'C': return Key.named(Key.Type.RIGHT);
            case 'D': return Key.named(Key.Type.LEFT);
            case 'H': return Key.named(Key.Type.HOME);
            case 'F': return Key.named(Key.Type.END);
            default:  return Key.named(Key.Type.UNKNOWN);
        }
    }
}
