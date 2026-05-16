package scheme;

import java.nio.charset.StandardCharsets;
import java.util.List;

public class SchemeHttpResponse {
    public int status;
    public List<String[]> headers; // each entry: [name, value]
    public String body;
    public byte[] bodyBytes;

    public SchemeHttpResponse(int status, List<String[]> headers, String body) {
        this.status = status;
        this.headers = headers;
        this.body = body;
        this.bodyBytes = null;
    }

    public SchemeHttpResponse(int status, List<String[]> headers, byte[] bodyBytes) {
        this.status = status;
        this.headers = headers;
        this.body = "";
        this.bodyBytes = bodyBytes;
    }

    public byte[] getBodyBytes() {
        return bodyBytes != null ? bodyBytes : body.getBytes(StandardCharsets.UTF_8);
    }

    @Override
    public String toString() { return "#<http-response " + status + ">"; }
}
