using System;
using System.IO;
using System.Security.Cryptography;

namespace scheme;

public class PrimitiveSHA256File : Primitive
{
    public override string Name() => "sha256-file";

    public override string Info() =>
        "Syntax: (sha256-file path)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns the SHA-256 hash of the contents of the file at path as a bytevector. The file\n" +
        "  is read in pieces, so it may be larger than memory.\n" +
        "Example:\n" +
        "  (bytevector->hex (sha256-file \"upload.bin\")) => \"9f86d0...\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string path = new string(Value.AsString(arguments[0]));
        try
        {
            using var f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
            return SHA256.HashData(f);
        }
        catch (Exception e) when (e is IOException || e is UnauthorizedAccessException)
        {
            throw new SchemeError(pos, "sha256-file: ~a", e.Message);
        }
    }
}
