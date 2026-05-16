using System.Text;

namespace scheme;

public class Encodings
{
    private static Encoding utf8 = new UTF8Encoding();
    private static Encoding utf8bom = new UTF8Encoding(true);
    
    public static Encoding GetEncoding(string encoding)
    {
        switch (encoding.ToLower())
        {
            case "utf8":
            case "utf-8":
                return utf8;
                
            case "utf8bom":
            case "utf-8-bom":
                return utf8bom;
                
            case "latin-1":
            case "iso-8859-1":
            case "iso88591":
                return Encoding.Latin1;
                
            case "utf-16":
            case "utf16":
                return Encoding.Unicode;
                
            case "utf-16-le":
            case "utf-16le":
            case "utf16-le":
            case "utf16le":
                return Encoding.Unicode;

            default:
                return utf8;
        }
    }

    public static bool IsEncoding(string encoding)
    {
        switch (encoding.ToLower())
        {
            case "utf8":
            case "utf-8":
            case "utf8bom":
            case "utf-8-bom":
            case "latin-1":
            case "iso-8859-1":
            case "iso88591":
            case "utf-16":
            case "utf16":
            case "utf-16-le":
            case "utf-16le":
            case "utf16-le":
            case "utf16le":
                return true;

            default:
                return false;
        }
    }
}
