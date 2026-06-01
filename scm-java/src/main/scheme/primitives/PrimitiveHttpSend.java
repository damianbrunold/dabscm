package scheme.primitives;
import scheme.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

public class PrimitiveHttpSend extends Primitive {
    @Override
    public String name() { return "http-send"; }

    @Override
    public String info() {
        return "Syntax: (http-send request)\n" +
               "Library: (scm net http client)\n" +
               "Description: Sends an HTTP request object and returns an http-response object.\n" +
               "Example:\n" +
               "  (http-send (make-http-request \"DELETE\" \"http://example.com/x\" '() #f))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeHttpRequest req = (SchemeHttpRequest) Value.asNativeValue(arguments[0]).value;
        try {
            HttpRequest.BodyPublisher bodyPub = req.body != null
                ? HttpRequest.BodyPublishers.ofString(req.body)
                : HttpRequest.BodyPublishers.noBody();
            var builder = HttpRequest.newBuilder()
                .uri(URI.create(req.url))
                .method(req.method, bodyPub);
            if (req.timeoutSeconds > 0) {
                builder.timeout(Duration.ofSeconds(req.timeoutSeconds));
            }
            for (String[] h : req.headers) {
                builder.header(h[0], h[1]);
            }
            HttpClient client = HttpClient.newHttpClient();
            HttpResponse<String> resp = client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
            return PrimitiveHttpGet.buildResponse(resp);
        } catch (Exception e) {
            throw new SchemeError(pos, "http-send: " + e.getMessage());
        }
    }
}
