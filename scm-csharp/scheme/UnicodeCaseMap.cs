using System.Globalization;
using System.Text;

namespace scheme;

/// <summary>
/// Full Unicode case mapping with special case support.
/// Handles one-to-many mappings from Unicode SpecialCasing.txt and CaseFolding.txt
/// that CultureInfo.InvariantCulture misses.
/// </summary>
public static class UnicodeCaseMap
{
    public static string ToUpper(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (char c in s)
        {
            switch (c)
            {
                case '\u00DF': sb.Append("SS"); break;       // ß → SS
                case '\u0149': sb.Append("\u02BCN"); break;   // ŉ → ʼN
                case '\u01F0': sb.Append("J\u030C"); break;   // ǰ → J̌ (J + combining caron)
                case '\u0390': sb.Append("\u0399\u0308\u0301"); break; // ΐ → Ϊ́
                case '\u03B0': sb.Append("\u03A5\u0308\u0301"); break; // ΰ → Ϋ́
                case '\uFB00': sb.Append("FF"); break;        // ﬀ → FF
                case '\uFB01': sb.Append("FI"); break;        // ﬁ → FI
                case '\uFB02': sb.Append("FL"); break;        // ﬂ → FL
                case '\uFB03': sb.Append("FFI"); break;       // ﬃ → FFI
                case '\uFB04': sb.Append("FFL"); break;       // ﬄ → FFL
                case '\uFB05': sb.Append("ST"); break;        // ﬅ → ST
                case '\uFB06': sb.Append("ST"); break;        // ﬆ → ST
                default:
                    sb.Append(char.ToUpper(c, CultureInfo.InvariantCulture));
                    break;
            }
        }
        return sb.ToString();
    }

    public static string ToLower(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (char c in s)
        {
            switch (c)
            {
                case '\u0130': // İ → i + combining dot above
                    sb.Append('i');
                    sb.Append('\u0307');
                    break;
                default:
                    sb.Append(char.ToLower(c, CultureInfo.InvariantCulture));
                    break;
            }
        }
        return sb.ToString();
    }

    public static string ToFold(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (char c in s)
        {
            switch (c)
            {
                case '\u00DF': sb.Append("ss"); break;        // ß → ss
                case '\u0130': // İ → i + combining dot above
                    sb.Append('i');
                    sb.Append('\u0307');
                    break;
                case '\u017F': sb.Append('s'); break;          // ſ → s (long s)
                case '\uFB00': sb.Append("ff"); break;
                case '\uFB01': sb.Append("fi"); break;
                case '\uFB02': sb.Append("fl"); break;
                case '\uFB03': sb.Append("ffi"); break;
                case '\uFB04': sb.Append("ffl"); break;
                case '\uFB05': sb.Append("st"); break;
                case '\uFB06': sb.Append("st"); break;
                default:
                    sb.Append(char.ToLower(c, CultureInfo.InvariantCulture));
                    break;
            }
        }
        return sb.ToString();
    }
}
