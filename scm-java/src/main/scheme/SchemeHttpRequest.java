package scheme;

import java.util.List;

public class SchemeHttpRequest {
    public String method;
    public String url;
    public List<String[]> headers; // each entry: [name, value]
    public String body; // null if no body — UTF-8 view of bodyBytes (for back-compat).
    public byte[] bodyBytes; // null if no body — the raw, byte-correct body.

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
