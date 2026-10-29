using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace scheme;

public class SchemeHttpResponse
{
    public int Status;
    public List<(string Name, string Value)> Headers;
    public string Body;
    public byte[]? BodyBytes;
    public string? FilePath;    // body: this part of a file (make-http-file-response)
    public long FileOffset;
    public long FileLength;
    public Lambda? Writer;      // body: written by this procedure (make-http-stream-response)
    public Lambda? WebSocket;   // no body: the connection becomes a WebSocket for this procedure (http-websocket-upgrade)

    public SchemeHttpResponse(int status, List<(string, string)> headers, string body)
    {
        Status = status;
        Headers = headers;
        Body = body;
        BodyBytes = null;
    }

    public SchemeHttpResponse(int status, List<(string, string)> headers, byte[] bodyBytes)
    {
        Status = status;
        Headers = headers;
        Body = "";
        BodyBytes = bodyBytes;
    }

    public static SchemeHttpResponse OfFile(int status, List<(string, string)> headers,
                                            string path, long offset, long length)
    {
        var r = new SchemeHttpResponse(status, headers, "");
        r.FilePath = path;
        r.FileOffset = offset;
        r.FileLength = length;
        return r;
    }

    public static SchemeHttpResponse OfWriter(int status, List<(string, string)> headers, Lambda writer)
    {
        var r = new SchemeHttpResponse(status, headers, "");
        r.Writer = writer;
        return r;
    }

    public static SchemeHttpResponse OfWebSocket(List<(string, string)> headers, Lambda handler)
    {
        var r = new SchemeHttpResponse(101, headers, "");
        r.WebSocket = handler;
        return r;
    }

    // The body length when known in advance, else -1 (a streamed body).
    public long BodyLength()
    {
        if (Writer != null || WebSocket != null) return -1;
        if (FilePath != null) return FileLength;
        return GetBodyBytes().Length;
    }

    // The whole body in memory: for a file body, its part of the file.
    public byte[] GetBodyBytes()
    {
        if (Writer != null)
            throw new SchemeError("http-response-body: a streamed response has no body to read");
        if (WebSocket != null)
            throw new SchemeError("http-response-body: a WebSocket upgrade has no body");
        if (FilePath != null)
        {
            if (FileLength > int.MaxValue - 16)
                throw new SchemeError("http-response-body: file part too large to read into memory");
            var buf = new byte[FileLength];
            try
            {
                using var f = new FileStream(FilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                f.Seek(FileOffset, SeekOrigin.Begin);
                f.ReadExactly(buf, 0, buf.Length);
            }
            catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
            {
                throw new SchemeError("http-response-body: ~a", e.Message);
            }
            return buf;
        }
        return BodyBytes ?? Encoding.UTF8.GetBytes(Body);
    }

    public override string ToString() => $"#<http-response {Status}>";
}
