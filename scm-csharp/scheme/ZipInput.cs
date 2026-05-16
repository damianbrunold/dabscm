using System.IO.Compression;

namespace scheme;

public class ZipInput : IDisposable
{
    public ZipArchive zip;
    public ZipInput(ZipArchive zip) { this.zip = zip; }
    public void Dispose() => zip.Dispose();
}
