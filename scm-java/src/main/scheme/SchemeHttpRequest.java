package scheme;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class SchemeHttpRequest {
    // Default request timeout in seconds. A value <= 0 means "no timeout".
    public static final int DEFAULT_TIMEOUT_SECONDS = 600;

    public String method;
    public String url;
    public List<String[]> headers; // each entry: [name, value]
    public String body; // null if no body — UTF-8 view of bodyBytes (for back-compat).
    public byte[] bodyBytes; // null if no body — the raw, byte-correct body.
    public Path bodyFile; // a large body received by tcp-http-serve, spooled to a file
                          // (bodyBytes and body are then read from it on demand)
    public int timeoutSeconds = DEFAULT_TIMEOUT_SECONDS; // <= 0 means no timeout
    public boolean followRedirects = true; // false: http-send returns the 3xx itself

    public SchemeHttpRequest(String method, String url, List<String[]> headers, String body) {
        this(method, url, headers, body, null);
    }

    public SchemeHttpRequest(String method, String url, List<String[]> headers,
                             String body, byte[] bodyBytes) {
        this.method = method;
        this.url = url;
        this.headers = headers;
        this.body = body;
        this.bodyBytes = bodyBytes;
    }

    // The body bytes, read from the spool file if needed; null if none.
    public byte[] getBodyBytes() {
        if (bodyBytes == null && bodyFile != null) {
            try { bodyBytes = Files.readAllBytes(bodyFile); }
            catch (IOException e) { throw new SchemeError("http-request-body: cannot read the spooled body: ~a", e.getMessage()); }
        }
        return bodyBytes;
    }

    // The body decoded as UTF-8; null if none.
    public String getBody() {
        if (body == null && getBodyBytes() != null) body = new String(bodyBytes, StandardCharsets.UTF_8);
        return body;
    }

    @Override
    public String toString() { return "#<http-request " + method + " " + url + ">"; }
}
