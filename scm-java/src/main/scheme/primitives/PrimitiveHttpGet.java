package scheme.primitives;
import scheme.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveHttpGet extends Primitive {
    @Override
    public String name() { return "http-get"; }

    @Override
    public String info() {
        return "Syntax: (http-get url) (http-get url headers) (http-get url headers timeout-seconds)\n" +
               "Library: (scm net http client)\n" +
               "Description: Performs an HTTP GET request and returns an http-response object.\n" +
               "  Optional timeout-seconds overrides the default request timeout (600s); <= 0 means no timeout.\n" +
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
            HttpClient client = HttpClient.newHttpClient();
            HttpResponse<String> resp = client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
            return buildResponse(resp);
        } catch (Exception e) {
            throw new SchemeError(pos, "http-get: " + e.getMessage());
        }
    }

    static NativeValue buildResponse(HttpResponse<String> resp) {
        int status = resp.statusCode();
        List<String[]> headers = new ArrayList<>();
        resp.headers().map().forEach((k, vs) -> {
            for (String v : vs) headers.add(new String[]{k, v});
        });
        String body = resp.body();
        return new NativeValue(new SchemeHttpResponse(status, headers, body));
    }
}
