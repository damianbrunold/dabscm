package scheme.primitives;
import scheme.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class PrimitiveHttpPost extends Primitive {
    @Override
    public String name() { return "http-post"; }

    @Override
    public String info() {
        return "Syntax: (http-post url body) (http-post url body headers)\n" +
               "Library: (scm net http client)\n" +
               "Description: Performs an HTTP POST request with the given body string and returns an http-response object.\n" +
               "Example:\n" +
               "  (http-post \"http://example.com/api\" \"{}\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        String url = new String(Value.asString(arguments[0]));
        String body = new String(Value.asString(arguments[1]));
        try {
            var builder = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .POST(HttpRequest.BodyPublishers.ofString(body));
            if (arguments.length == 3) {
                Object hlist = arguments[2];
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
            return PrimitiveHttpGet.buildResponse(resp);
        } catch (Exception e) {
            throw new SchemeError(pos, "http-post: " + e.getMessage());
        }
    }
}
