package scheme;

/**
 * Full Unicode case mapping with special case support.
 * Handles one-to-many mappings from Unicode SpecialCasing.txt and CaseFolding.txt.
 */
public class UnicodeCaseMap {

    public static String toUpper(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\u00DF': sb.append("SS"); break;       // ß → SS
                case '\u0149': sb.append("\u02BCN"); break;   // ŉ → ʼN
                case '\u01F0': sb.append("J\u030C"); break;   // ǰ → J̌
                case '\u0390': sb.append("\u0399\u0308\u0301"); break;
                case '\u03B0': sb.append("\u03A5\u0308\u0301"); break;
                case '\uFB00': sb.append("FF"); break;
                case '\uFB01': sb.append("FI"); break;
                case '\uFB02': sb.append("FL"); break;
                case '\uFB03': sb.append("FFI"); break;
                case '\uFB04': sb.append("FFL"); break;
                case '\uFB05': sb.append("ST"); break;
                case '\uFB06': sb.append("ST"); break;
                default:
                    sb.append(Character.toUpperCase(c));
                    break;
            }
        }
        return sb.toString();
    }

    public static String toLower(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\u0130': // İ → i + combining dot above
                    sb.append('i');
                    sb.append('\u0307');
                    break;
                default:
                    sb.append(Character.toLowerCase(c));
                    break;
            }
        }
        return sb.toString();
    }

    public static String toFold(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\u00DF': sb.append("ss"); break;        // ß → ss
                case '\u0130': // İ → i + combining dot above
                    sb.append('i');
                    sb.append('\u0307');
                    break;
                case '\u017F': sb.append('s'); break;          // ſ → s
                case '\uFB00': sb.append("ff"); break;
                case '\uFB01': sb.append("fi"); break;
                case '\uFB02': sb.append("fl"); break;
                case '\uFB03': sb.append("ffi"); break;
                case '\uFB04': sb.append("ffl"); break;
                case '\uFB05': sb.append("st"); break;
                case '\uFB06': sb.append("st"); break;
                default:
                    sb.append(Character.toLowerCase(c));
                    break;
            }
        }
        return sb.toString();
    }
}
