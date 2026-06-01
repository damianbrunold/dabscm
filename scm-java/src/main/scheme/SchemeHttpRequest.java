package scheme;

import java.util.List;

public class SchemeHttpRequest {
    // Default request timeout in seconds. A value <= 0 means "no timeout".
    public static final int DEFAULT_TIMEOUT_SECONDS = 600;

    public String method;
    public String url;
    public List<String[]> headers; // each entry: [name, value]
    public String body; // null if no body — UTF-8 view of bodyBytes (for back-compat).
    public byte[] bodyBytes; // null if no body — the raw, byte-correct body.
    public int timeoutSeconds = DEFAULT_TIMEOUT_SECONDS; // <= 0 means no timeout

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

    @Override
    public String toString() { return "#<http-request " + method + " " + url + ">"; }
}
