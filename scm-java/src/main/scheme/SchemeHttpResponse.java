package scheme;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.List;

public class SchemeHttpResponse {
    public int status;
    public List<String[]> headers; // each entry: [name, value]
    public String body;
    public byte[] bodyBytes;
    public String filePath;   // body: this part of a file (make-http-file-response)
    public long fileOffset;
    public long fileLength;
    public Lambda writer;     // body: written by this procedure (make-http-stream-response)
    public Lambda websocket;  // no body: the connection becomes a WebSocket for this procedure (http-websocket-upgrade)

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

    public static SchemeHttpResponse ofFile(int status, List<String[]> headers,
                                            String path, long offset, long length) {
        SchemeHttpResponse r = new SchemeHttpResponse(status, headers, "");
        r.filePath = path;
        r.fileOffset = offset;
        r.fileLength = length;
        return r;
    }

    public static SchemeHttpResponse ofWriter(int status, List<String[]> headers, Lambda writer) {
        SchemeHttpResponse r = new SchemeHttpResponse(status, headers, "");
        r.writer = writer;
        return r;
    }

    public static SchemeHttpResponse ofWebSocket(List<String[]> headers, Lambda handler) {
        SchemeHttpResponse r = new SchemeHttpResponse(101, headers, "");
        r.websocket = handler;
        return r;
    }

    // The body length when known in advance, else -1 (a streamed body).
    public long bodyLength() {
        if (writer != null || websocket != null) return -1;
        if (filePath != null) return fileLength;
        return getBodyBytes().length;
    }

    // The whole body in memory: for a file body, its part of the file.
    public byte[] getBodyBytes() {
        if (writer != null)
            throw new SchemeError("http-response-body: a streamed response has no body to read");
        if (websocket != null)
            throw new SchemeError("http-response-body: a WebSocket upgrade has no body");
        if (filePath != null) {
            if (fileLength > Integer.MAX_VALUE - 16)
                throw new SchemeError("http-response-body: file part too large to read into memory");
            byte[] buf = new byte[(int) fileLength];
            try (RandomAccessFile f = new RandomAccessFile(filePath, "r")) {
                f.seek(fileOffset);
                f.readFully(buf);
            } catch (IOException e) {
                throw new SchemeError("http-response-body: ~a", e.getMessage());
            }
            return buf;
        }
        return bodyBytes != null ? bodyBytes : body.getBytes(StandardCharsets.UTF_8);
    }

    @Override
    public String toString() { return "#<http-response " + status + ">"; }
}
