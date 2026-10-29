using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace scheme;

public class PrimitiveTcpHttpServe : Primitive
{
    private const int DefaultMaxThreads = 32;
    private const string DefaultHost = "0.0.0.0";
    private const int DefaultReadTimeoutMs = 30_000;
    private const long DefaultMaxBodyBytes = 4 * 1024 * 1024;
    private const long DefaultSpoolThreshold = 1024 * 1024;
    private const int DefaultGracefulStopMs = 10_000;

    private Modules modules;

    public PrimitiveTcpHttpServe(Modules modules) => this.modules = modules;

    public override string Name() => "tcp-http-serve";

    public override string Info() =>
        "Syntax: (tcp-http-serve port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms [spool-threshold-bytes]]]]]])\n" +
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

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 8);
        int port = IntegerMath.ToInt(arguments[0]);
        Lambda handler = Value.AsLambda(arguments[1]);
        int maxThreads = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : 0;
        if (maxThreads <= 0) maxThreads = DefaultMaxThreads;
        string host = arguments.Length > 3 ? new String(Value.AsString(arguments[3])) : "";
        if (string.IsNullOrEmpty(host)) host = DefaultHost;
        int readTimeoutMs = arguments.Length > 4 ? IntegerMath.ToInt(arguments[4]) : 0;
        if (readTimeoutMs <= 0) readTimeoutMs = DefaultReadTimeoutMs;
        long maxBodyBytes = arguments.Length > 5 ? IntegerMath.ToLong(arguments[5]) : 0;
        if (maxBodyBytes <= 0) maxBodyBytes = DefaultMaxBodyBytes;
        int gracefulStopMs = arguments.Length > 6 ? IntegerMath.ToInt(arguments[6]) : 0;
        if (gracefulStopMs <= 0) gracefulStopMs = DefaultGracefulStopMs;
        long spoolThreshold = arguments.Length > 7 ? IntegerMath.ToLong(arguments[7]) : 0;
        if (spoolThreshold <= 0) spoolThreshold = DefaultSpoolThreshold;

        var sem = new SemaphoreSlim(maxThreads, maxThreads);

        var cts = new CancellationTokenSource();
        var token = cts.Token;
        IPAddress bindAddr;
        try { bindAddr = IPAddress.Parse(host); }
        catch (Exception) { bindAddr = IPAddress.Any; }
        var listener = new TcpListener(bindAddr, port);
        listener.Start();

        var serverTask = Task.Factory.StartNew(() =>
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    TcpClient client;
                    try
                    {
                        client = listener.AcceptTcpClientAsync(token).AsTask().GetAwaiter().GetResult();
                    }
                    catch (OperationCanceledException) { break; }
                    catch (ObjectDisposedException) { break; }
                    // Bound concurrency: if the pool is saturated, reject with 503
                    // rather than queueing or blocking the accept loop. This keeps
                    // memory bounded under load and gives clients fast feedback.
                    if (!sem.Wait(0, token))
                    {
                        try
                        {
                            using (client)
                            {
                                var s = client.GetStream();
                                string r503 = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                var b503 = Encoding.UTF8.GetBytes(r503);
                                s.Write(b503, 0, b503.Length);
                            }
                        }
                        catch { }
                        continue;
                    }
                    Task.Factory.StartNew((obj) =>
                    {
                        var tcpClient = (TcpClient)obj!;
                        HttpBody? spooled = null;
                        try
                        {
                            tcpClient.ReceiveTimeout = readTimeoutMs;
                            tcpClient.SendTimeout = readTimeoutMs;
                            using (tcpClient)
                            {
                                var stream = tcpClient.GetStream();
                                // Read headers byte-by-byte so binary body bytes that
                                // follow are not consumed/decoded by a text reader.
                                var headerBuf = new MemoryStream(1024);
                                int matched = 0; // matches in "\r\n\r\n"
                                while (matched < 4)
                                {
                                    int b = stream.ReadByte();
                                    if (b < 0) return; // client closed
                                    headerBuf.WriteByte((byte)b);
                                    if ((matched == 0 || matched == 2) && b == (byte)'\r') matched++;
                                    else if ((matched == 1 || matched == 3) && b == (byte)'\n') matched++;
                                    else matched = 0;
                                    if (headerBuf.Length > 64 * 1024) return; // header bomb
                                }
                                // ISO-8859-1 decodes any byte 0..255 unambiguously
                                // to chars 0..255 so header text is preserved.
                                string header = Encoding.GetEncoding("ISO-8859-1").GetString(headerBuf.ToArray());
                                if (header.EndsWith("\r\n\r\n"))
                                    header = header.Substring(0, header.Length - 4);
                                var lines = header.Split("\r\n");
                                if (lines.Length == 0) return;
                                var parts = lines[0].Split(' ');
                                if (parts.Length < 2) return;
                                string method = parts[0];
                                string url = parts[1];
                                List<(string, string)> headers = new();
                                long contentLength = 0;
                                bool badLength = false;
                                bool chunked = false;
                                for (int i = 1; i < lines.Length; i++)
                                {
                                    string line = lines[i];
                                    if (line.Length == 0) continue;
                                    int colon = line.IndexOf(':');
                                    if (colon > 0)
                                    {
                                        string hname = line.Substring(0, colon).Trim();
                                        string hval = line.Substring(colon + 1).Trim();
                                        headers.Add((hname, hval));
                                        if (hname.Equals("Content-Length", StringComparison.OrdinalIgnoreCase))
                                            badLength = !long.TryParse(hval, out contentLength);
                                        if (hname.Equals("Transfer-Encoding", StringComparison.OrdinalIgnoreCase)
                                            && hval.Equals("chunked", StringComparison.OrdinalIgnoreCase))
                                            chunked = true;
                                    }
                                }
                                if (badLength || contentLength < 0)
                                {
                                    WriteStatusOnly(stream, 400);
                                    return;
                                }
                                if (!chunked && contentLength > maxBodyBytes)
                                {
                                    WriteStatusOnly(stream, 413);
                                    LingerClose(tcpClient, stream);
                                    return;
                                }
                                byte[]? bodyBytes = null;
                                string? bodyFile = null;
                                if (chunked || contentLength > 0)
                                {
                                    spooled = HttpBody.Read(stream, chunked ? -1 : contentLength, maxBodyBytes, spoolThreshold);
                                    if (spooled.TooLarge) { WriteStatusOnly(stream, 413); LingerClose(tcpClient, stream); return; }
                                    if (spooled.Malformed) { WriteStatusOnly(stream, 400); LingerClose(tcpClient, stream); return; }
                                    bodyBytes = spooled.Bytes;
                                    bodyFile = spooled.File;
                                }
                                // The UTF-8 string view (http-request-body) is
                                // decoded on demand.
                                var schemeReq = new SchemeHttpRequest(method, url, headers, null, bodyBytes);
                                schemeReq.BodyFile = bodyFile;
                                var reqNV = new NativeValue(schemeReq);

                                // Call Scheme handler
                                SchemeHttpResponse schemeResp;
                                try
                                {
                                    VM vm = new VM(modules);
                                    Lambda wrapper = new Lambda(Value.NIL, Instruction.Seq(
                                        new Instruction(Opcode.ARGS, 0),
                                        new Instruction(Opcode.CONST, reqNV),
                                        new Instruction(Opcode.CONST, handler),
                                        new Instruction(Opcode.CALLJ, 1)));
                                    object result = vm.Execute(wrapper);
                                    if (Value.IsNativeValue(result) && Value.AsNativeValue(result).value is SchemeHttpResponse sr)
                                        schemeResp = sr;
                                    else
                                    {
                                        LogHandlerError(method, url, "handler did not return an http-response");
                                        schemeResp = new SchemeHttpResponse(500, new List<(string,string)>(), "Internal Server Error");
                                    }
                                }
                                catch (Exception ex)
                                {
                                    // The error text can carry request data or
                                    // internals: log it, never send it.
                                    LogHandlerError(method, url, "raised: " + ex.Message);
                                    schemeResp = new SchemeHttpResponse(500, new List<(string,string)>(), "Internal Server Error");
                                }

                                if (schemeResp.WebSocket != null)
                                {
                                    Upgrade(tcpClient, stream, method, url, headers, schemeResp);
                                    return;
                                }

                                // Write response
                                var sb = new StringBuilder();
                                sb.Append($"HTTP/1.1 {schemeResp.Status} {StatusText(schemeResp.Status)}\r\n");
                                bool hasContentType = false;
                                bool hasContentLength = false;
                                foreach (var (hnRaw, hvRaw) in schemeResp.Headers)
                                {
                                    // Strip any CR/LF/NUL the handler may have
                                    // placed into a header value: those would
                                    // split the response and let a caller
                                    // inject arbitrary headers.
                                    string hn = SanitizeHeader(hnRaw);
                                    string hv = SanitizeHeader(hvRaw);
                                    sb.Append($"{hn}: {hv}\r\n");
                                    if (hn.Equals("Content-Type", StringComparison.OrdinalIgnoreCase)) hasContentType = true;
                                    if (hn.Equals("Content-Length", StringComparison.OrdinalIgnoreCase)) hasContentLength = true;
                                }
                                byte[]? respBytes = schemeResp.FilePath == null && schemeResp.Writer == null
                                    ? schemeResp.GetBodyBytes() : null;
                                long length = respBytes != null ? respBytes.Length : schemeResp.BodyLength();
                                // A streamed body has no length: it ends when
                                // the connection closes.
                                if (!hasContentLength && length >= 0)
                                    sb.Append($"Content-Length: {length}\r\n");
                                if (!hasContentType)
                                    sb.Append("Content-Type: text/plain; charset=utf-8\r\n");
                                sb.Append("Connection: close\r\n\r\n");
                                byte[] headerBytes = Encoding.UTF8.GetBytes(sb.ToString());
                                stream.Write(headerBytes, 0, headerBytes.Length);
                                // HEAD: the headers of the GET response
                                // (Content-Length included), no body.
                                if (!string.Equals(method, "HEAD", StringComparison.OrdinalIgnoreCase))
                                {
                                    if (respBytes != null) stream.Write(respBytes, 0, respBytes.Length);
                                    else if (schemeResp.FilePath != null) SendFilePart(stream, schemeResp);
                                    else WriteStream(stream, schemeResp.Writer!, method, url);
                                }
                                stream.Flush();
                            }
                        }
                        catch (IOException) { /* slow/dropped client — silent */ }
                        catch (SocketException) { /* slow/dropped client — silent */ }
                        catch (Exception ex)
                        {
                            Console.Error.WriteLine("tcp-http-serve handler error: " + ex.Message);
                        }
                        finally
                        {
                            spooled?.Discard();
                            sem.Release();
                        }
                    }, client);
                }
                catch (Exception ex)
                {
                    if (!token.IsCancellationRequested)
                        Console.WriteLine("tcp-http-serve accept error: " + ex.Message);
                }
            }
            listener.Stop();
        }, token, TaskCreationOptions.LongRunning, TaskScheduler.Default);

        var server = new SchemeServer(cts, serverTask, listener);
        server.sem = sem;
        server.maxThreads = maxThreads;
        server.gracefulStopMs = gracefulStopMs;
        return new NativeValue(server);
    }

    private static void WriteStatusOnly(Stream stream, int status)
    {
        string r = $"HTTP/1.1 {status} {StatusText(status)}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        var bytes = Encoding.UTF8.GetBytes(r);
        stream.Write(bytes, 0, bytes.Length);
    }

    // After an early error response: stop sending, and read what the
    // client still sends (up to 16 MB or 2 s) before closing, so that a
    // client busy uploading gets to read the response instead of a reset.
    private static void LingerClose(TcpClient client, Stream stream)
    {
        try
        {
            stream.Flush();
            client.Client.Shutdown(SocketShutdown.Send);
            client.ReceiveTimeout = 2000;
            var buf = new byte[65536];
            long left = 16L * 1024 * 1024;
            var deadline = DateTime.UtcNow.AddSeconds(2);
            while (left > 0 && DateTime.UtcNow < deadline)
            {
                int r = stream.Read(buf, 0, buf.Length);
                if (r <= 0) break;
                left -= r;
            }
        }
        catch (Exception e) when (e is IOException || e is SocketException || e is ObjectDisposedException)
        {
        }
    }

    private static void SendFilePart(Stream stream, SchemeHttpResponse resp)
    {
        using var f = new FileStream(resp.FilePath!, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        f.Seek(resp.FileOffset, SeekOrigin.Begin);
        var buf = new byte[65536];
        long left = resp.FileLength;
        while (left > 0)
        {
            int r = f.Read(buf, 0, (int)Math.Min(buf.Length, left));
            if (r <= 0) break; // the file shrank: the client sees a short body
            stream.Write(buf, 0, r);
            left -= r;
        }
    }

    // A write-only stream that remembers whether writing to the client failed.
    private sealed class TrackingStream : Stream
    {
        private readonly Stream inner;
        public bool Failed;
        public TrackingStream(Stream inner) => this.inner = inner;
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count)
        {
            try { inner.Write(buffer, offset, count); }
            catch (Exception) { Failed = true; throw; }
        }
        public override void Flush()
        {
            try { inner.Flush(); }
            catch (Exception) { Failed = true; throw; }
        }
    }

    private static string? HeaderValue(List<(string, string)> headers, string name)
    {
        foreach (var (hn, hv) in headers)
            if (hn.Equals(name, StringComparison.OrdinalIgnoreCase)) return hv;
        return null;
    }

    // True if a comma-separated header value has token (case-insensitive).
    private static bool HasToken(string? value, string token)
    {
        if (value == null) return false;
        foreach (var t in value.Split(','))
            if (t.Trim().Equals(token, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    // The handler returned http-websocket-upgrade: check the handshake
    // (RFC 6455, 4.2.1), switch protocols, and run (handler ws) on this
    // connection; it holds one of the server's threads until it returns.
    private void Upgrade(TcpClient client, Stream stream, string method, string url,
                         List<(string, string)> headers, SchemeHttpResponse resp)
    {
        string? key = HeaderValue(headers, "Sec-WebSocket-Key");
        if (method != "GET" || !HasToken(HeaderValue(headers, "Upgrade"), "websocket")
            || !HasToken(HeaderValue(headers, "Connection"), "upgrade") || string.IsNullOrEmpty(key))
        {
            WriteStatusOnly(stream, 400);
            return;
        }
        if (HeaderValue(headers, "Sec-WebSocket-Version") != "13")
        {
            var b426 = Encoding.UTF8.GetBytes("HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\n"
                + "Content-Length: 0\r\nConnection: close\r\n\r\n");
            stream.Write(b426, 0, b426.Length);
            return;
        }
        var sb = new StringBuilder();
        sb.Append("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n");
        sb.Append("Sec-WebSocket-Accept: ").Append(SchemeWebSocket.AcceptKey(key)).Append("\r\n");
        foreach (var (hn, hv) in resp.Headers)
            sb.Append(SanitizeHeader(hn)).Append(": ").Append(SanitizeHeader(hv)).Append("\r\n");
        sb.Append("\r\n");
        var head = Encoding.UTF8.GetBytes(sb.ToString());
        stream.Write(head, 0, head.Length);
        stream.Flush();
        // A WebSocket may be quiet for long; see ws-receive's timeout.
        client.ReceiveTimeout = 0;
        client.SendTimeout = 0;
        client.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.KeepAlive, true);
        var ws = new SchemeWebSocket(stream, true, client);
        try
        {
            VM vm = new VM(modules);
            Lambda wrapper = new Lambda(Value.NIL, Instruction.Seq(
                new Instruction(Opcode.ARGS, 0),
                new Instruction(Opcode.CONST, new NativeValue(ws)),
                new Instruction(Opcode.CONST, resp.WebSocket!),
                new Instruction(Opcode.CALLJ, 1)));
            vm.Execute(wrapper);
        }
        catch (Exception ex)
        {
            if (!ws.IsClosed) LogHandlerError(method, url, "websocket handler raised: " + ex.Message);
        }
        finally
        {
            ws.Close(1000);
            ws.Shutdown();
        }
    }

    // Calls (writer port) with a binary port to the client.
    private void WriteStream(Stream stream, Lambda writer, string method, string url)
    {
        var tracked = new TrackingStream(stream);
        var port = new BinaryOutputStream(tracked);
        try
        {
            VM vm = new VM(modules);
            Lambda wrapper = new Lambda(Value.NIL, Instruction.Seq(
                new Instruction(Opcode.ARGS, 0),
                new Instruction(Opcode.CONST, port),
                new Instruction(Opcode.CONST, writer),
                new Instruction(Opcode.CALLJ, 1)));
            vm.Execute(wrapper);
        }
        catch (Exception ex)
        {
            // A client that went away ends the body normally; anything
            // else is the writer's error.
            if (!tracked.Failed) LogHandlerError(method, url, "stream writer raised: " + ex.Message);
        }
        if (!tracked.Failed) port.Flush();
    }

    private static string SanitizeHeader(string s)
    {
        if (s == null) return "";
        var b = new StringBuilder(s.Length);
        foreach (var c in s)
        {
            if (c == '\r' || c == '\n' || c == '\0') continue;
            b.Append(c);
        }
        return b.ToString();
    }

    // One stderr line in the (scm log) format:
    //   YYYY-MM-DD HH:MM:SS ERROR [http] <method> <url> <detail>
    private static void LogHandlerError(string method, string url, string detail)
    {
        string ts = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
        Console.Error.WriteLine($"{ts} ERROR [http] {method} {url} {detail}");
    }

    private static string StatusText(int status) => status switch
    {
        100 => "Continue",
        101 => "Switching Protocols",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        204 => "No Content",
        206 => "Partial Content",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        307 => "Temporary Redirect",
        308 => "Permanent Redirect",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        406 => "Not Acceptable",
        408 => "Request Timeout",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Payload Too Large",
        414 => "URI Too Long",
        415 => "Unsupported Media Type",
        416 => "Range Not Satisfiable",
        422 => "Unprocessable Content",
        428 => "Precondition Required",
        429 => "Too Many Requests",
        431 => "Request Header Fields Too Large",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        _ => "Unknown"
    };
}
