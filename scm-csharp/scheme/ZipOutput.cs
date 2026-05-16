using System.IO.Compression;

namespace scheme;

public class ZipOutput : IDisposable
{
    public ZipArchive? zip;
    public Stream? bin_strm;
    public StreamWriter? text_strm;
    public MemoryStream? mem_strm;   // non-null for in-memory (bytevector) zips


    public void Dispose()
    {
        this.bin_strm?.Dispose();
        this.text_strm?.Dispose();
	    this.zip?.Dispose();
        // Do NOT dispose mem_strm here — needed for GetBytes() after zip is closed
    }

}
