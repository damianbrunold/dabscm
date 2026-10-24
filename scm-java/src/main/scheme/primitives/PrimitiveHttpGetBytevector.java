package scheme.primitives;
import scheme.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveHttpGetBytevector extends Primitive {
    @Override
    public String name() { return "http-get-bytevector"; }

    @Override
    public String info() {
        return "Syntax: (http-get-bytevector url) (http-get-bytevector url headers) (http-get-bytevector url headers timeout-seconds)\n" +
               "Library: (scm net http client)\n" +
               "Description: Performs an HTTP GET request like http-get, but keeps the body as it\n" +
               "  arrived: http-response-body of the response returned is a bytevector. Use it for\n" +
               "  downloading binary files such as images or ZIP archives.\n" +
               "Example:\n" +
               "  (bytevector-length (http-response-body (http-get-bytevector \"http://example.com/a.zip\"))) => 81234";
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
            List<String[]> headers = new ArrayList<>();
            resp.headers().map().forEach((k, vs) -> {
                for (String v : vs) headers.add(new String[]{k, v});
            });
            return new NativeValue(new SchemeHttpResponse(resp.statusCode(), headers, resp.body()));
        } catch (Exception e) {
            throw new SchemeError(pos, "http-get-bytevector: " + TlsTrust.errorText(e));
        }
    }
}
