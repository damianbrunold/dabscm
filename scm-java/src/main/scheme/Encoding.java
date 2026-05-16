package scheme;

import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

public class Encoding {

    public static Charset getEncoding(String encoding) {
        switch (encoding.toLowerCase()) {
            case "utf8":
            case "utf-8":
                return StandardCharsets.UTF_8;

            case "utf8bom":
            case "utf-8-bom":
                return StandardCharsets.UTF_8;

            case "latin-1":
            case "iso-8859-1":
            case "iso88591":
                return StandardCharsets.ISO_8859_1;

            case "utf-16":
            case "utf16":
                return StandardCharsets.UTF_16;

            case "utf-16-be":
            case "utf-16be":
            case "utf16-be":
            case "utf16be":
                return StandardCharsets.UTF_16BE;

            case "utf-16-le":
            case "utf-16le":
            case "utf16-le":
            case "utf16le":
                return StandardCharsets.UTF_16LE;

            default:
                return StandardCharsets.UTF_8;
        }
    }

    public static boolean isEncoding(String encoding) {
        switch (encoding.toLowerCase()) {
            case "utf8":
            case "utf-8":
            case "utf8bom":
            case "utf-8-bom":
            case "latin-1":
            case "iso-8859-1":
            case "iso88591":
            case "utf-16":
            case "utf16":
            case "utf-16-be":
            case "utf-16be":
            case "utf16-be":
            case "utf16be":
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
