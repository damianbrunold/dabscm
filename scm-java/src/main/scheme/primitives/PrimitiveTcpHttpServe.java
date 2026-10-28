package scheme.primitives;
import scheme.*;
import java.io.*;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;

public class PrimitiveTcpHttpServe extends Primitive {
    private static final int DEFAULT_MAX_THREADS = 32;
    private static final String DEFAULT_HOST = "0.0.0.0";
    private static final int DEFAULT_READ_TIMEOUT_MS = 30_000;
    private static final long DEFAULT_MAX_BODY_BYTES = 4 * 1024 * 1024;
    private static final long DEFAULT_SPOOL_THRESHOLD = 1024 * 1024;
    private static final int DEFAULT_GRACEFUL_STOP_MS = 10_000;

    private Modules modules;

    public PrimitiveTcpHttpServe(Modules modules) { this.modules = modules; }

    @Override
    public String name() { return "tcp-http-serve"; }

    @Override
    public String info() {
        return "Syntax: (tcp-http-serve port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms [spool-threshold-bytes]]]]]])\n" +
               "Library: (scm net http server)\n" +
               "Description: Starts an HTTP server on the given port. handler is called with each " +
               "incoming http-request and must return an http-response. Returns a server object. " +
               "Use server-stop to shut it down. Notes: request bodies come with Content-Length or " +
               "Transfer-Encoding: chunked; bodies larger than max-body-bytes are rejected with 413, and bodies " +
               "larger than spool-threshold-bytes are written to a temporary file (http-request-body-file) " +
               "that is deleted after the response; per-connection read-timeout-ms guards against slow " +
               "clients; max-threads bounds concurrency (excess connections are rejected with 503). Responses " +
               "may be file responses (sent from the file) or streamed (make-http-stream-response). 0 or " +
               "omitted parameters use defaults: max-threads=32, host=\"0.0.0.0\", read-timeout-ms=30000, " +
               "max-body-bytes=4194304, graceful-stop-ms=10000, spool-threshold-bytes=1048576.\n" +
               "Example:\n" +
               "  (define s (tcp-http-serve 8080 (lambda (req) (http-ok \"Hello\"))))\n" +
               "  (define s (tcp-http-serve 8080 handler 16 \"127.0.0.1\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 8);
        int port = IntegerMath.toInt(arguments[0]);
        Lambda handler = Value.asLambda(arguments[1]);
        int maxThreads = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : 0;
        if (maxThreads <= 0) maxThreads = DEFAULT_MAX_THREADS;
        String host = arguments.length > 3 ? new String(Value.asString(arguments[3])) : "";
        if (host.isEmpty()) host = DEFAULT_HOST;
        int readTimeoutMs = arguments.length > 4 ? IntegerMath.toInt(arguments[4]) : 0;
        if (readTimeoutMs <= 0) readTimeoutMs = DEFAULT_READ_TIMEOUT_MS;
        long maxBodyBytes = arguments.length > 5 ? IntegerMath.toLong(arguments[5]) : 0;
        if (maxBodyBytes <= 0) maxBodyBytes = DEFAULT_MAX_BODY_BYTES;
        int gracefulStopMs = arguments.length > 6 ? IntegerMath.toInt(arguments[6]) : 0;
        if (gracefulStopMs <= 0) gracefulStopMs = DEFAULT_GRACEFUL_STOP_MS;
        long spoolThreshold = arguments.length > 7 ? IntegerMath.toLong(arguments[7]) : 0;
        if (spoolThreshold <= 0) spoolThreshold = DEFAULT_SPOOL_THRESHOLD;

        final int maxThreadsF = maxThreads;
        final int readTimeoutF = readTimeoutMs;
        final long maxBodyF = maxBodyBytes;
        final long spoolF = spoolThreshold;

        SchemeServer server;
        try {
            ServerSocket serverSocket = new ServerSocket();
            serverSocket.bind(new InetSocketAddress(InetAddress.getByName(host), port));
            server = new SchemeServer(null);
            server.serverSocket = serverSocket;
            server.maxThreads = maxThreadsF;
            server.gracefulStopMs = gracefulStopMs;
            // Fixed pool bounds threads; the semaphore enforces "reject when full"
            // semantics so requests get a fast 503 instead of unbounded queueing.
            ExecutorService executor = Executors.newFixedThreadPool(maxThreadsF);
            server.executor = executor;
            Semaphore sem = new Semaphore(maxThreadsF);
            server.sem = sem;

            Thread t = new Thread(() -> {
                while (server.running.get()) {
                    try {
                        if (serverSocket.isClosed()) break;
                        Socket client;
                        try { client = serverSocket.accept(); }
                        catch (java.net.SocketException e) { break; }

                        if (!sem.tryAcquire()) {
                            try (Socket cc = client) {
                                String r503 = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                cc.getOutputStream().write(r503.getBytes(StandardCharsets.UTF_8));
                            } catch (Exception ignored) {}
                            continue;
                        }

                        executor.submit(() -> {
                            HttpBody spooled = null;
                            try (Socket c = client) {
                                c.setSoTimeout(readTimeoutF);
                                InputStream raw = c.getInputStream();
                                // Read headers byte-by-byte so binary body bytes that
                                // follow are not consumed/decoded by a text Reader.
                                ByteArrayOutputStream headerBuf = new ByteArrayOutputStream(1024);
                                int matched = 0; // matches in "\r\n\r\n"
                                while (matched < 4) {
                                    int b = raw.read();
                                    if (b < 0) return; // client closed
                                    headerBuf.write(b);
                                    if ((matched == 0 || matched == 2) && b == '\r') matched++;
                                    else if ((matched == 1 || matched == 3) && b == '\n') matched++;
                                    else matched = 0;
                                    if (headerBuf.size() > 64 * 1024) return; // header bomb
                                }
                                // HTTP/1.1 headers are 7-bit ASCII; ISO-8859-1 decodes
                                // any byte 0..255 unambiguously to chars 0..255 so
                                // we never lose data.
                                String header = headerBuf.toString(StandardCharsets.ISO_8859_1);
                                // Strip the trailing CRLFCRLF.
                                if (header.endsWith("\r\n\r\n"))
                                    header = header.substring(0, header.length() - 4);
                                String[] lines = header.split("\r\n", -1);
                                if (lines.length == 0) return;
                                String[] parts = lines[0].split(" ");
                                if (parts.length < 2) return;
                                String method = parts[0];
                                String url = parts[1];
                                List<String[]> headers = new ArrayList<>();
                                long contentLength = 0;
                                boolean badLength = false;
                                boolean chunked = false;
                                for (int i = 1; i < lines.length; i++) {
                                    String line = lines[i];
                                    if (line.isEmpty()) continue;
                                    int colon = line.indexOf(':');
                                    if (colon > 0) {
                                        String hname = line.substring(0, colon).trim();
                                        String hval = line.substring(colon + 1).trim();
                                        headers.add(new String[]{hname, hval});
                                        if (hname.equalsIgnoreCase("Content-Length")) {
                                            try { contentLength = Long.parseLong(hval); }
                                            catch (Exception e) { badLength = true; }
                                        }
                                        if (hname.equalsIgnoreCase("Transfer-Encoding") && hval.equalsIgnoreCase("chunked"))
                                            chunked = true;
                                    }
                                }
                                OutputStream out = c.getOutputStream();
                                if (badLength || contentLength < 0) {
                                    writeStatusOnly(out, 400);
                                    return;
                                }
                                if (!chunked && contentLength > maxBodyF) {
                                    writeStatusOnly(out, 413);
                                    lingerClose(c, raw);
                                    return;
                                }
                                byte[] bodyBytes = null;
                                java.nio.file.Path bodyFile = null;
                                if (chunked || contentLength > 0) {
                                    spooled = HttpBody.read(raw, chunked ? -1 : contentLength, maxBodyF, spoolF);
                                    if (spooled.tooLarge) { writeStatusOnly(out, 413); lingerClose(c, raw); return; }
                                    if (spooled.malformed) { writeStatusOnly(out, 400); lingerClose(c, raw); return; }
                                    bodyBytes = spooled.bytes;
                                    bodyFile = spooled.file;
                                }
                                // The UTF-8 string view (http-request-body) is
                                // decoded on demand.
                                SchemeHttpRequest req = new SchemeHttpRequest(method, url, headers, null, bodyBytes);
                                req.bodyFile = bodyFile;
                                NativeValue reqNV = new NativeValue(req);

                                SchemeHttpResponse resp;
                                try {
                                    VM vm = new VM(modules);
                                    Lambda wrapper = new Lambda(Value.NIL, Instruction.seq(
                                        new Instruction(Opcode.ARGS, 0),
                                        new Instruction(Opcode.CONST, reqNV),
                                        new Instruction(Opcode.CONST, handler),
                                        new Instruction(Opcode.CALLJ, 1)));
                                    Object result = vm.execute(wrapper);
                                    if (Value.isNativeValue(result) && Value.asNativeValue(result).value instanceof SchemeHttpResponse) {
                                        resp = (SchemeHttpResponse) Value.asNativeValue(result).value;
                                    } else {
                                        logHandlerError(method, url, "handler did not return an http-response");
                                        resp = new SchemeHttpResponse(500, new ArrayList<>(), "Internal Server Error");
                                    }
                                } catch (Exception ex) {
                                    // The error text can carry request data or
                                    // internals: log it, never send it.
                                    logHandlerError(method, url, "raised: " + ex.getMessage());
                                    resp = new SchemeHttpResponse(500, new ArrayList<>(), "Internal Server Error");
                                }

                                StringBuilder sb = new StringBuilder();
                                sb.append("HTTP/1.1 ").append(resp.status).append(" ").append(statusText(resp.status)).append("\r\n");
                                boolean hasContentLength = false;
                                boolean hasContentType = false;
                                for (String[] h : resp.headers) {
                                    // Strip any CR/LF/NUL the handler may have
                                    // placed into a header value: those would
                                    // split the response and let a caller
                                    // inject arbitrary headers.
                                    String hn = sanitizeHeader(h[0]);
                                    String hv = sanitizeHeader(h[1]);
                                    sb.append(hn).append(": ").append(hv).append("\r\n");
                                    if (hn.equalsIgnoreCase("Content-Length")) hasContentLength = true;
                                    if (hn.equalsIgnoreCase("Content-Type")) hasContentType = true;
                                }
                                byte[] respBytes = resp.filePath == null && resp.writer == null
                                    ? resp.getBodyBytes() : null;
                                long length = respBytes != null ? respBytes.length : resp.bodyLength();
                                // A streamed body has no length: it ends when
                                // the connection closes.
                                if (!hasContentLength && length >= 0) sb.append("Content-Length: ").append(length).append("\r\n");
                                if (!hasContentType) sb.append("Content-Type: text/plain; charset=utf-8\r\n");
                                sb.append("Connection: close\r\n\r\n");
                                out.write(sb.toString().getBytes(StandardCharsets.UTF_8));
                                // HEAD: the headers of the GET response
                                // (Content-Length included), no body.
                                if (!method.equalsIgnoreCase("HEAD")) {
                                    if (respBytes != null) out.write(respBytes);
                                    else if (resp.filePath != null) sendFilePart(out, resp);
                                    else writeStream(out, resp.writer, method, url);
                                }
                                out.flush();
                            } catch (java.net.SocketTimeoutException ex) {
                                // slow client — silent
                            } catch (java.io.IOException ex) {
                                // dropped client — silent
                            } catch (Exception ex) {
                                System.err.println("tcp-http-serve handler error: " + ex.getMessage());
                            } finally {
                                if (spooled != null) spooled.discard();
                                sem.release();
                            }
                        });
                    } catch (Exception ex) {
                        if (server.running.get())
                            System.err.println("tcp-http-serve accept error: " + ex.getMessage());
                    }
                }
                try { serverSocket.close(); } catch (Exception ignored) {}
            });
            t.setDaemon(true);
            server.thread = t;
            t.start();
        } catch (Exception e) {
            throw new SchemeError(pos, "tcp-http-serve: " + e.getMessage());
        }

        return new NativeValue(server);
    }

    private static void writeStatusOnly(OutputStream out, int status) throws IOException {
        String r = "HTTP/1.1 " + status + " " + statusText(status)
            + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        out.write(r.getBytes(StandardCharsets.UTF_8));
    }

    // After an early error response: stop sending, and read what the
    // client still sends (up to 16 MB or 2 s) before closing, so that a
    // client busy uploading gets to read the response instead of a reset.
    private static void lingerClose(Socket c, InputStream in) {
        try {
            c.getOutputStream().flush();
            c.shutdownOutput();
            c.setSoTimeout(2000);
            byte[] buf = new byte[65536];
            long left = 16L * 1024 * 1024;
            long deadline = System.currentTimeMillis() + 2000;
            while (left > 0 && System.currentTimeMillis() < deadline) {
                int r = in.read(buf);
                if (r < 0) break;
                left -= r;
            }
        } catch (IOException ignored) {
        }
    }

    private static void sendFilePart(OutputStream out, SchemeHttpResponse resp) throws IOException {
        try (RandomAccessFile f = new RandomAccessFile(resp.filePath, "r")) {
            f.seek(resp.fileOffset);
            byte[] buf = new byte[65536];
            long left = resp.fileLength;
            while (left > 0) {
                int r = f.read(buf, 0, (int) Math.min(buf.length, left));
                if (r <= 0) break; // the file shrank: the client sees a short body
                out.write(buf, 0, r);
                left -= r;
            }
        }
    }

    // Calls (writer port) with a binary port to the client.
    private void writeStream(OutputStream out, Lambda writer, String method, String url) throws IOException {
        BinaryOutputStream port = new BinaryOutputStream(out, false);
        try {
            VM vm = new VM(modules);
            Lambda wrapper = new Lambda(Value.NIL, Instruction.seq(
                new Instruction(Opcode.ARGS, 0),
                new Instruction(Opcode.CONST, port),
                new Instruction(Opcode.CONST, writer),
                new Instruction(Opcode.CALLJ, 1)));
            vm.execute(wrapper);
        } catch (Exception ex) {
            // Mostly a client that went away; the body just ends.
            logHandlerError(method, url, "stream writer raised: " + ex.getMessage());
        }
        port.flush();
    }

    private static String sanitizeHeader(String s) {
        if (s == null) return "";
        StringBuilder b = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\r' || c == '\n' || c == '\0') continue;
            b.append(c);
        }
        return b.toString();
    }

    // One stderr line in the (scm log) format:
    //   YYYY-MM-DD HH:MM:SS ERROR [http] <method> <url> <detail>
    private static void logHandlerError(String method, String url, String detail) {
        String ts = java.time.LocalDateTime.now()
            .format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        System.err.println(ts + " ERROR [http] " + method + " " + url + " " + detail);
    }

    private static String statusText(int status) {
        switch (status) {
            case 100: return "Continue";
            case 101: return "Switching Protocols";
            case 200: return "OK";
            case 201: return "Created";
            case 202: return "Accepted";
            case 204: return "No Content";
            case 206: return "Partial Content";
            case 301: return "Moved Permanently";
            case 302: return "Found";
            case 303: return "See Other";
            case 304: return "Not Modified";
            case 307: return "Temporary Redirect";
            case 308: return "Permanent Redirect";
            case 400: return "Bad Request";
            case 401: return "Unauthorized";
            case 403: return "Forbidden";
            case 404: return "Not Found";
            case 405: return "Method Not Allowed";
            case 406: return "Not Acceptable";
            case 408: return "Request Timeout";
            case 409: return "Conflict";
            case 410: return "Gone";
            case 411: return "Length Required";
            case 412: return "Precondition Failed";
            case 413: return "Payload Too Large";
            case 414: return "URI Too Long";
            case 415: return "Unsupported Media Type";
            case 416: return "Range Not Satisfiable";
            case 422: return "Unprocessable Content";
            case 428: return "Precondition Required";
            case 429: return "Too Many Requests";
            case 431: return "Request Header Fields Too Large";
            case 500: return "Internal Server Error";
            case 501: return "Not Implemented";
            case 502: return "Bad Gateway";
            case 503: return "Service Unavailable";
            case 504: return "Gateway Timeout";
            default:  return "Unknown";
        }
    }
}
