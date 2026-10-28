using System;
using System.IO;
using System.Text;

namespace scheme;

// Reads the body of an HTTP request for tcp-http-serve: Content-Length
// bytes, or a Transfer-Encoding: chunked body. Bodies up to the spool
// threshold stay in memory; larger ones go to a temporary file, so a
// large upload does not need its size in memory. The caller deletes the
// file when the request is done.
public sealed class HttpBody
{
    public byte[]? Bytes;    // the body, if kept in memory
    public string? File;     // the body, if spooled
    public long Size;
    public bool TooLarge;
    public bool Malformed;

    private readonly long maxBody;
    private readonly long spoolThreshold;
    private MemoryStream? mem = new MemoryStream();
    private FileStream? fileOut;

    private HttpBody(long maxBody, long spoolThreshold)
    {
        this.maxBody = maxBody;
        this.spoolThreshold = spoolThreshold;
    }

    // length: the Content-Length, or -1 for a chunked body.
    public static HttpBody Read(Stream input, long length, long maxBody, long spoolThreshold)
    {
        var b = new HttpBody(maxBody, spoolThreshold);
        try
        {
            if (length >= 0) b.ReadFixed(input, length);
            else b.ReadChunked(input);
        }
        finally
        {
            b.Finish();
        }
        return b;
    }

    private void Append(byte[] buf, int n)
    {
        if (Size + n > maxBody) { TooLarge = true; return; }
        if (fileOut == null && Size + n > spoolThreshold)
        {
            File = Path.Combine(Path.GetTempPath(), "scm-http-" + Guid.NewGuid().ToString("N") + ".body");
            fileOut = new FileStream(File, FileMode.CreateNew, FileAccess.Write);
            mem!.WriteTo(fileOut);
            mem = null;
        }
        if (fileOut != null) fileOut.Write(buf, 0, n);
        else mem!.Write(buf, 0, n);
        Size += n;
    }

    private void ReadFixed(Stream input, long length)
    {
        var buf = new byte[65536];
        long left = length;
        while (left > 0 && !TooLarge)
        {
            int r = input.Read(buf, 0, (int)Math.Min(buf.Length, left));
            if (r <= 0) break; // client closed early: keep what arrived
            Append(buf, r);
            left -= r;
        }
    }

    private static string? ReadLine(Stream input)
    {
        var sb = new StringBuilder();
        for (;;)
        {
            int c = input.ReadByte();
            if (c < 0) return null;
            if (c == '\n') break;
            if (c != '\r') sb.Append((char)c);
            if (sb.Length > 4096) return null;
        }
        return sb.ToString();
    }

    private void ReadChunked(Stream input)
    {
        var buf = new byte[65536];
        for (;;)
        {
            string? line = ReadLine(input);
            if (line == null) { Malformed = true; return; }
            int semi = line.IndexOf(';');
            string hex = (semi >= 0 ? line.Substring(0, semi) : line).Trim();
            if (!long.TryParse(hex, System.Globalization.NumberStyles.AllowHexSpecifier, null, out long n) || n < 0)
            {
                Malformed = true;
                return;
            }
            if (n == 0)
            {
                // Trailer fields, up to an empty line.
                for (;;)
                {
                    string? t = ReadLine(input);
                    if (t == null || t.Length == 0) return;
                }
            }
            if (Size + n > maxBody) { TooLarge = true; return; }
            long left = n;
            while (left > 0)
            {
                int r = input.Read(buf, 0, (int)Math.Min(buf.Length, left));
                if (r <= 0) { Malformed = true; return; }
                Append(buf, r);
                left -= r;
            }
            string? crlf = ReadLine(input);
            if (crlf == null || crlf.Length != 0) { Malformed = true; return; }
        }
    }

    private void Finish()
    {
        fileOut?.Dispose();
        if (TooLarge || Malformed) { Discard(); return; }
        if (File == null) Bytes = mem!.ToArray();
    }

    public void Discard()
    {
        if (File != null)
        {
            try { System.IO.File.Delete(File); } catch { }
        }
    }
}
