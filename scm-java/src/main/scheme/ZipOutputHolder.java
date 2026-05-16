package scheme;

import java.io.ByteArrayOutputStream;
import java.util.zip.ZipOutputStream;

public class ZipOutputHolder {
    public ZipOutputStream zip;
    public ByteArrayOutputStream mem; // null for file-based zips

    public ZipOutputHolder(ZipOutputStream zip, ByteArrayOutputStream mem) {
        this.zip = zip;
        this.mem = mem;
    }
}
