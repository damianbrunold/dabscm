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
    private const int DefaultMaxBodyBytes = 4 * 1024 * 1024;
    private const int DefaultGracefulStopMs = 10_000;

    private Modules modules;

    public PrimitiveTcpHttpServe(Modules modules) => this.modules = modules;

    public override string Name() => "tcp-http-serve";

    public override string Info() =>
        "Syntax: (tcp-http-serve port handler [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])\n" +
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

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 7);
        int port = IntegerMath.ToInt(arguments[0]);
        Lambda handler = Value.AsLambda(arguments[1]);
        int maxThreads = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : 0;
        if (maxThreads <= 0) maxThreads = DefaultMaxThreads;
        string host = arguments.Length > 3 ? new String(Value.AsString(arguments[3])) : "";
        if (string.IsNullOrEmpty(host)) host = DefaultHost;
        int readTimeoutMs = arguments.Length > 4 ? IntegerMath.ToInt(arguments[4]) : 0;
        if (readTimeoutMs <= 0) readTimeoutMs = DefaultReadTimeoutMs;
        int maxBodyBytes = arguments.Length > 5 ? IntegerMath.ToInt(arguments[5]) : 0;
        if (maxBodyBytes <= 0) maxBodyBytes = DefaultMaxBodyBytes;
        int gracefulStopMs = arguments.Length > 6 ? IntegerMath.ToInt(arguments[6]) : 0;
        if (gracefulStopMs <= 0) gracefulStopMs = DefaultGracefulStopMs;

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
                                int contentLength = 0;
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
                                            int.TryParse(hval, out contentLength);
                                        if (hname.Equals("Transfer-Encoding", StringComparison.OrdinalIgnoreCase)
                                            && hval.Equals("chunked", StringComparison.OrdinalIgnoreCase))
                                            chunked = true;
                                    }
                                }
                                if (chunked)
                                {
                                    string resp501 = "HTTP/1.1 501 Not Implemented\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                    var bytes501 = Encoding.UTF8.GetBytes(resp501);
                                    stream.Write(bytes501, 0, bytes501.Length);
                                    return;
                                }
                                if (contentLength < 0 || contentLength > maxBodyBytes)
                                {
                                    string resp413 = "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                                    var bytes413 = Encoding.UTF8.GetBytes(resp413);
                                    stream.Write(bytes413, 0, bytes413.Length);
                                    return;
                                }
                                // Read body as raw bytes.
                                byte[]? bodyBytes = null;
                                string? body = null;
                                if (contentLength > 0)
                                {
                                    bodyBytes = new byte[contentLength];
                                    int read = 0;
                                    while (read < contentLength)
                                    {
                                        int r = stream.Read(bodyBytes, read, contentLength - read);
                                        if (r <= 0) break;
                                        read += r;
                                    }
                                    if (read < contentLength)
                                    {
                                        Array.Resize(ref bodyBytes, read);
                                    }
                                    body = Encoding.UTF8.GetString(bodyBytes);
                                }
                                var schemeReq = new SchemeHttpRequest(method, url, headers, body, bodyBytes);
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
                                        schemeResp = new SchemeHttpResponse(500, new List<(string,string)>(), "Internal Server Error: handler did not return http-response");
                                }
                                catch (Exception ex)
                                {
                                    schemeResp = new SchemeHttpResponse(500, new List<(string,string)>(), "Internal Server Error: " + ex.Message);
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
                                byte[] respBytes = schemeResp.GetBodyBytes();
                                if (!hasContentLength)
                                    sb.Append($"Content-Length: {respBytes.Length}\r\n");
                                if (!hasContentType)
                                    sb.Append("Content-Type: text/plain; charset=utf-8\r\n");
                                sb.Append("Connection: close\r\n\r\n");
                                byte[] headerBytes = Encoding.UTF8.GetBytes(sb.ToString());
                                stream.Write(headerBytes, 0, headerBytes.Length);
                                stream.Write(respBytes, 0, respBytes.Length);
                                stream.Flush();
                            }
                        }
                        catch (IOException) { /* slow/dropped client — silent */ }
                        catch (SocketException) { /* slow/dropped client — silent */ }
                        catch (Exception ex)
                        {
                            Console.WriteLine("tcp-http-serve handler error: " + ex.Message);
                        }
                        finally
                        {
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

    private static string StatusText(int status) => status switch
    {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        413 => "Payload Too Large",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        503 => "Service Unavailable",
        _ => "Unknown"
    };
}
