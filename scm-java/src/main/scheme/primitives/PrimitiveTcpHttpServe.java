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
    private static final int DEFAULT_MAX_BODY_BYTES = 4 * 1024 * 1024;
    private static final int DEFAULT_GRACEFUL_STOP_MS = 10_000;

    private Modules modules;

    public PrimitiveTcpHttpServe(Modules modules) { this.modules = modules; }

    @Override
    public String name() { return "tcp-http-serve"; }

    @Override
    public String info() {
        return "Syntax: (tcp-http-serve port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])\n" +
               "Library: (scm net http server)\n" +
               "Description: Starts an HTTP server on the given port. handler is called with each " +
               "incoming http-request and must return an http-response. Returns a server object. " +
               "Use server-stop to shut it down. Notes: Transfer-Encoding: chunked is not supported (501); " +
               "requests larger than max-body-bytes are rejected with 413; per-connection read-timeout-ms " +
               "guards against slow clients; max-threads bounds concurrency (excess connections are rejected " +
               "with 503). 0 or omitted parameters use defaults: max-threads=32, host=\"0.0.0.0\", " +
               "read-timeout-ms=30000, max-body-bytes=4194304, graceful-stop-ms=10000.\n" +
               "Example:\n" +
               "  (define s (tcp-http-serve 8080 (lambda (req) (http-ok \"Hello\"))))\n" +
               "  (define s (tcp-http-serve 8080 handler 16 \"127.0.0.1\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 7);
        int port = IntegerMath.toInt(arguments[0]);
        Lambda handler = Value.asLambda(arguments[1]);
        int maxThreads = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : 0;
        if (maxThreads <= 0) maxThreads = DEFAULT_MAX_THREADS;
        String host = arguments.length > 3 ? new String(Value.asString(arguments[3])) : "";
        if (host.isEmpty()) host = DEFAULT_HOST;
        int readTimeoutMs = arguments.length > 4 ? IntegerMath.toInt(arguments[4]) : 0;
        if (readTimeoutMs <= 0) readTimeoutMs = DEFAULT_READ_TIMEOUT_MS;
        int maxBodyBytes = arguments.length > 5 ? IntegerMath.toInt(arguments[5]) : 0;
        if (maxBodyBytes <= 0) maxBodyBytes = DEFAULT_MAX_BODY_BYTES;
        int gracefulStopMs = arguments.length > 6 ? IntegerMath.toInt(arguments[6]) : 0;
        if (gracefulStopMs <= 0) gracefulStopMs = DEFAULT_GRACEFUL_STOP_MS;

        final int maxThreadsF = maxThreads;
        final int readTimeoutF = readTimeoutMs;
        final int maxBodyF = maxBodyBytes;

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
                                int contentLength = 0;
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
                                            try { contentLength = Integer.parseInt(hval); } catch (Exception ignored) {}
                                        }
                                        if (hname.equalsIgnoreCase("Transfer-Encoding") && hval.equalsIgnoreCase("chunked"))
                                            chunked = true;
                                    }
                                }
                                OutputStream out = c.getOutputStream();
                                if (chunked) {
                                    String r501 = "HTTP/1.1 501 Not Implemented\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                    out.write(r501.getBytes(StandardCharsets.UTF_8));
                                    return;
                                }
                                if (contentLength < 0 || contentLength > maxBodyF) {
                                    String r413 = "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                    out.write(r413.getBytes(StandardCharsets.UTF_8));
                                    return;
                                }
                                byte[] bodyBytes = null;
                                String body = null;
                                if (contentLength > 0) {
                                    bodyBytes = new byte[contentLength];
                                    int read = 0;
                                    while (read < contentLength) {
                                        int r = raw.read(bodyBytes, read, contentLength - read);
                                        if (r <= 0) break;
                                        read += r;
                                    }
                                    if (read < contentLength) {
                                        byte[] trimmed = new byte[read];
                                        System.arraycopy(bodyBytes, 0, trimmed, 0, read);
                                        bodyBytes = trimmed;
                                    }
                                    // Keep the legacy String view for handlers that
                                    // still call http-request-body. It is a UTF-8
                                    // decode of the bytes; binary clients must use
                                    // http-request-body-bytes instead.
                                    body = new String(bodyBytes, StandardCharsets.UTF_8);
                                }
                                SchemeHttpRequest req = new SchemeHttpRequest(method, url, headers, body, bodyBytes);
                                NativeValue reqNV = new NativeValue(req);

                                SchemeHttpResponse resp;
                                try {
                                    VM vm = new VM(modules.deepClone());
                                    Lambda wrapper = new Lambda(Value.NIL, Instruction.seq(
                                        new Instruction(Opcode.ARGS, 0),
                                        new Instruction(Opcode.CONST, reqNV),
                                        new Instruction(Opcode.CONST, handler),
                                        new Instruction(Opcode.CALLJ, 1)));
                                    Object result = vm.execute(wrapper);
                                    if (Value.isNativeValue(result) && Value.asNativeValue(result).value instanceof SchemeHttpResponse) {
                                        resp = (SchemeHttpResponse) Value.asNativeValue(result).value;
                                    } else
                                        resp = new SchemeHttpResponse(500, new ArrayList<>(), "Internal Server Error: handler did not return http-response");
                                } catch (Exception ex) {
                                    resp = new SchemeHttpResponse(500, new ArrayList<>(), "Internal Server Error: " + ex.getMessage());
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
                                byte[] respBytes = resp.getBodyBytes();
                                if (!hasContentLength) sb.append("Content-Length: ").append(respBytes.length).append("\r\n");
                                if (!hasContentType) sb.append("Content-Type: text/plain; charset=utf-8\r\n");
                                sb.append("Connection: close\r\n\r\n");
                                out.write(sb.toString().getBytes(StandardCharsets.UTF_8));
                                out.write(respBytes);
                                out.flush();
                            } catch (java.net.SocketTimeoutException ex) {
                                // slow client — silent
                            } catch (java.io.IOException ex) {
                                // dropped client — silent
                            } catch (Exception ex) {
                                System.err.println("tcp-http-serve handler error: " + ex.getMessage());
                            } finally {
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

    private static String statusText(int status) {
        if (status == 200) return "OK";
        if (status == 201) return "Created";
        if (status == 204) return "No Content";
        if (status == 400) return "Bad Request";
        if (status == 401) return "Unauthorized";
        if (status == 403) return "Forbidden";
        if (status == 404) return "Not Found";
        if (status == 405) return "Method Not Allowed";
        if (status == 413) return "Payload Too Large";
        if (status == 500) return "Internal Server Error";
        if (status == 501) return "Not Implemented";
        if (status == 503) return "Service Unavailable";
        return "Unknown";
    }
}
