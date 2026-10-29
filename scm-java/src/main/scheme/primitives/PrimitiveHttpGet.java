package scheme.primitives;
import scheme.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class PrimitiveHttpGet extends Primitive {
    @Override
    public String name() { return "http-get"; }

    @Override
    public String info() {
        return "Syntax: (http-get url) (http-get url headers) (http-get url headers timeout-seconds)\n" +
               "Library: (scm net http client)\n" +
               "Description: Performs an HTTP GET request and returns an http-response object.\n" +
               "  Optional timeout-seconds overrides the default request timeout (600s); <= 0 means no timeout.\n" +
               "  The body is a string when the response is text (Content-Type text/*, JSON, XML,\n" +
               "  JavaScript, form data, any type with a charset parameter such as\n" +
               "  application/x-sexp; charset=utf-8, or none), decoded by its charset (UTF-8 by\n" +
               "  default), and a bytevector otherwise (images, archives, ...), as it arrived.\n" +
               "Example:\n" +
               "  (http-response-status (http-get \"http://example.com/\")) => 200";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        String url = new String(Value.asString(arguments[0]));
        int timeoutSeconds = SchemeHttpRequest.DEFAULT_TIMEOUT_SECONDS;
        if (arguments.length == 3) {
            timeoutSeconds = Value.asInteger(arguments[2]).intValue();
        }
        try {
            var builder = HttpRequest.newBuilder().uri(URI.create(url)).GET();
            if (timeoutSeconds > 0) {
                builder.timeout(Duration.ofSeconds(timeoutSeconds));
            }
            if (arguments.length >= 2) {
                Object hlist = arguments[1];
                while (hlist != Value.NIL) {
                    Pair hp = (Pair) hlist;
                    Pair kv = (Pair) hp.car;
                    String key = new String(Value.asString(kv.car));
                    String val = new String(Value.asString(kv.cdr));
                    builder.header(key, val);
                    hlist = hp.cdr;
                }
            }
            HttpClient client = TlsTrust.httpClient();
            HttpResponse<byte[]> resp = client.send(builder.build(), HttpResponse.BodyHandlers.ofByteArray());
            return buildResponse(resp);
        } catch (Exception e) {
            throw new SchemeError(pos, "http-get: " + TlsTrust.errorText(e));
        }
    }

    // The body as http-get, http-post and http-send return it: decoded to a
    // string when the Content-Type says it is text (or says nothing), the
    // bytes as they arrived otherwise. Decoding an image or an archive as
    // text would corrupt it beyond repair.
    static NativeValue buildResponse(HttpResponse<byte[]> resp) {
        int status = resp.statusCode();
        List<String[]> headers = new ArrayList<>();
        resp.headers().map().forEach((k, vs) -> {
            for (String v : vs) headers.add(new String[]{k, v});
        });
        String contentType = resp.headers().firstValue("Content-Type").orElse(null);
        byte[] bytes = resp.body();
        if (!isText(contentType)) {
            return new NativeValue(new SchemeHttpResponse(status, headers, bytes));
        }
        return new NativeValue(new SchemeHttpResponse(status, headers, new String(bytes, charset(contentType))));
    }

    // Text: no type, text/*, the JSON/XML/JavaScript/form types, or any type
    // that names a charset (application/x-sexp; charset=utf-8) -- a charset
    // only makes sense for text. charset=binary is the one exception.
    static boolean isText(String contentType) {
        if (contentType == null) return true;
        String t = contentType.split(";", 2)[0].trim().toLowerCase(Locale.ROOT);
        if (t.isEmpty() || t.startsWith("text/")) return true;
        String cs = charsetName(contentType);
        if (cs != null && !cs.equalsIgnoreCase("binary")) return true;
        if (t.endsWith("+json") || t.endsWith("+xml")) return true;
        switch (t) {
            case "application/json":
            case "application/xml":
            case "application/javascript":
            case "application/ecmascript":
            case "application/x-www-form-urlencoded":
            case "application/x-ndjson":
                return true;
            default:
                return false;
        }
    }

    // The charset parameter of a Content-Type, null when there is none.
    static String charsetName(String contentType) {
        for (String part : contentType.split(";")) {
            String p = part.trim();
            if (p.toLowerCase(Locale.ROOT).startsWith("charset=")) {
                String cs = p.substring(8).trim().replace("\"", "");
                return cs.isEmpty() ? null : cs;
            }
        }
        return null;
    }

    static Charset charset(String contentType) {
        if (contentType != null) {
            for (String part : contentType.split(";")) {
                String p = part.trim();
                if (p.toLowerCase(Locale.ROOT).startsWith("charset=")) {
                    try {
                        return Charset.forName(p.substring(8).trim().replace("\"", ""));
                    } catch (Exception e) {
                        break;
                    }
                }
            }
        }
        return StandardCharsets.UTF_8;
    }
}
