using System.IO;

namespace scheme;

public class PrimitiveMakeHttpFileResponse : Primitive
{
    public override string Name() => "make-http-file-response";

    public override string Info() =>
        "Syntax: (make-http-file-response status headers path [offset [length]])\n" +
        "Library: (scm net http response)\n" +
        "Description: Creates an HTTP response whose body is a part of the file at path: length bytes from\n" +
        "  offset (default: from 0 to the end of the file). tcp-http-serve sends it straight from the file,\n" +
        "  so large files need not fit in memory. The file must exist and the part must lie within it.\n" +
        "  Content-Length is set from the length unless headers give one.\n" +
        "Example:\n" +
        "  (make-http-file-response 200 '((\"Content-Type\" . \"video/mp4\")) \"/srv/v.mp4\")\n" +
        "  (make-http-file-response 206 headers \"/srv/v.mp4\" 1000 500)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 5);
        int status = IntegerMath.ToInt(arguments[0]);
        string path = new string(Value.AsString(arguments[2]));
        var fi = new FileInfo(path);
        if (!fi.Exists) throw new SchemeError(pos, "make-http-file-response: not a file: ~a", path);
        long size = fi.Length;
        long offset = arguments.Length > 3 ? IntegerMath.ToLong(arguments[3]) : 0;
        long length = arguments.Length > 4 ? IntegerMath.ToLong(arguments[4]) : size - offset;
        if (offset < 0 || length < 0 || offset + length > size)
            throw new SchemeError(pos, "make-http-file-response: part outside the file: ~a+~a of ~a", offset, length, size);
        return new NativeValue(SchemeHttpResponse.OfFile(
            status, PrimitiveMakeHttpResponse.ParseHeaders(arguments[1]), path, offset, length));
    }
}
