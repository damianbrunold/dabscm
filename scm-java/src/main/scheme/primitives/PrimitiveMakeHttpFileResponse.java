package scheme.primitives;
import scheme.*;
import java.io.File;

public class PrimitiveMakeHttpFileResponse extends Primitive {
    @Override
    public String name() { return "make-http-file-response"; }

    @Override
    public String info() {
        return "Syntax: (make-http-file-response status headers path [offset [length]])\n" +
               "Library: (scm net http response)\n" +
               "Description: Creates an HTTP response whose body is a part of the file at path: length bytes from\n" +
               "  offset (default: from 0 to the end of the file). tcp-http-serve sends it straight from the file,\n" +
               "  so large files need not fit in memory. The file must exist and the part must lie within it.\n" +
               "  Content-Length is set from the length unless headers give one.\n" +
               "Example:\n" +
               "  (make-http-file-response 200 '((\"Content-Type\" . \"video/mp4\")) \"/srv/v.mp4\")\n" +
               "  (make-http-file-response 206 headers \"/srv/v.mp4\" 1000 500)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 5);
        int status = IntegerMath.toInt(arguments[0]);
        String path = new String(Value.asString(arguments[2]));
        File f = new File(path);
        if (!f.isFile()) throw new SchemeError(pos, "make-http-file-response: not a file: ~a", path);
        long size = f.length();
        long offset = arguments.length > 3 ? IntegerMath.toLong(arguments[3]) : 0;
        long length = arguments.length > 4 ? IntegerMath.toLong(arguments[4]) : size - offset;
        if (offset < 0 || length < 0 || offset + length > size)
            throw new SchemeError(pos, "make-http-file-response: part outside the file: ~a+~a of ~a", offset, length, size);
        return new NativeValue(SchemeHttpResponse.ofFile(
            status, PrimitiveMakeHttpResponse.parseHeaders(arguments[1]), path, offset, length));
    }
}
