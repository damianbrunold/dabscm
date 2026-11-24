using System.IO.Compression;

namespace scheme;

public class ZipOutput : IDisposable
{
    public ZipArchive? zip;
    public Stream? bin_strm;
    public StreamWriter? text_strm;
    public MemoryStream? mem_strm;   // non-null for in-memory (bytevector) zips
    // the port of the binary entry being written: it buffers in front of
    // bin_strm
    public BinaryOutputStream? bin_port;

    // Before the next entry or the end of the zip: the entry port's
    // buffered output goes into its entry (it was lost unless flushed),
    // then the entry's stream is closed
    public void FinishEntry()
    {
        bin_port?.Flush();
        bin_port = null;
        text_strm?.Dispose();
        bin_strm?.Dispose();
        text_strm = null;
        bin_strm = null;
    }


    public void Dispose()
    {
        this.bin_strm?.Dispose();
        this.text_strm?.Dispose();
	    this.zip?.Dispose();
        // Do NOT dispose mem_strm here — needed for GetBytes() after zip is closed
    }

}
