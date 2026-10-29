package scheme;

import java.io.ByteArrayOutputStream;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

/**
 * Image decoding and encoding for (scm image): PNG and JPEG to straight
 * (not premultiplied) RGBA, 8 bits per channel, rows top to bottom; resizing,
 * EXIF orientation and baseline JPEG encoding on such pixels.
 *
 * PNG: every colour type and bit depth, palettes, tRNS, Adam7 interlacing.
 * JPEG: baseline, extended and progressive Huffman-coded frames, restart
 * intervals, any sampling factors, grayscale, YCbCr, RGB, CMYK and YCCK
 * (Adobe). Arithmetic coding and lossless JPEG are refused.
 *
 * The same algorithms are in scm-csharp/scheme/ImageCodec.cs, so both
 * implementations produce the same pixels; keep them in step.
 */
public final class ImageCodec {
    private ImageCodec() {}

    /** A decoded image. */
    public static final class Image {
        public final int width, height;
        public final byte[] rgba;
        Image(int width, int height, byte[] rgba) {
            this.width = width; this.height = height; this.rgba = rgba;
        }
    }

    /** Thrown for malformed or unsupported data; primitives turn it into a SchemeError. */
    public static final class ImageException extends RuntimeException {
        public ImageException(String message) { super(message); }
    }

    static void checkSize(long w, long h, long maxPixels) {
        if (w <= 0 || h <= 0) throw new ImageException("bad image size");
        if (w * h > maxPixels)
            throw new ImageException("image too large (" + w + " x " + h + " pixels)");
    }

    public static Image decode(byte[] data, long maxPixels) {
        if (data.length >= 8 && (data[0] & 0xFF) == 0x89 && data[1] == 'P' && data[2] == 'N' && data[3] == 'G')
            return new Png(data, maxPixels).decode();
        if (data.length >= 3 && (data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8)
            return new Jpeg(data, maxPixels).decode();
        throw new ImageException("not a PNG or JPEG image");
    }

    // --- PNG -----------------------------------------------------------------

    static final class Png {
        final byte[] d;
        final long maxPixels;
        int width, height, depth, colorType, interlace;
        byte[] palette;            // RGB triples
        byte[] paletteAlpha;       // per entry, from tRNS
        int[] transparent;         // tRNS key of gray (1 sample) or RGB (3 samples), full precision

        Png(byte[] d, long maxPixels) { this.d = d; this.maxPixels = maxPixels; }

        int u32(int i) {
            return ((d[i] & 0xFF) << 24) | ((d[i + 1] & 0xFF) << 16) | ((d[i + 2] & 0xFF) << 8) | (d[i + 3] & 0xFF);
        }

        Image decode() {
            ByteArrayOutputStream idat = new ByteArrayOutputStream();
            int pos = 8;
            boolean header = false;
            while (pos + 8 <= d.length) {
                int len = u32(pos);
                if (len < 0 || pos + 12L + len > d.length) throw new ImageException("PNG: truncated chunk");
                String type = new String(d, pos + 4, 4, java.nio.charset.StandardCharsets.ISO_8859_1);
                int body = pos + 8;
                switch (type) {
                    case "IHDR":
                        if (len < 13) throw new ImageException("PNG: bad IHDR");
                        width = u32(body); height = u32(body + 4);
                        depth = d[body + 8] & 0xFF; colorType = d[body + 9] & 0xFF;
                        interlace = d[body + 12] & 0xFF;
                        checkSize(width & 0xFFFFFFFFL, height & 0xFFFFFFFFL, maxPixels);
                        if (!validDepth()) throw new ImageException("PNG: bad bit depth or colour type");
                        if (interlace > 1) throw new ImageException("PNG: bad interlace method");
                        header = true;
                        break;
                    case "PLTE":
                        palette = java.util.Arrays.copyOfRange(d, body, body + len);
                        break;
                    case "tRNS":
                        if (colorType == 3) {
                            paletteAlpha = java.util.Arrays.copyOfRange(d, body, body + len);
                        } else if (colorType == 0 && len >= 2) {
                            transparent = new int[] { ((d[body] & 0xFF) << 8) | (d[body + 1] & 0xFF) };
                        } else if (colorType == 2 && len >= 6) {
                            transparent = new int[3];
                            for (int i = 0; i < 3; i++)
                                transparent[i] = ((d[body + 2 * i] & 0xFF) << 8) | (d[body + 2 * i + 1] & 0xFF);
                        }
                        break;
                    case "IDAT":
                        idat.write(d, body, len);
                        break;
                    default:
                        break;
                }
                pos = body + len + 4;
                if (type.equals("IEND")) break;
            }
            if (!header) throw new ImageException("PNG: no IHDR");
            if (colorType == 3 && palette == null) throw new ImageException("PNG: no palette");
            byte[] raw = inflate(idat.toByteArray());
            byte[] out = new byte[width * height * 4];
            int nch = channels();
            int bitsPerPixel = nch * depth;
            int bpp = Math.max(1, bitsPerPixel / 8);
            if (interlace == 0) {
                int stride = (width * bitsPerPixel + 7) / 8;
                if (raw.length < (long) (stride + 1) * height) throw new ImageException("PNG: not enough image data");
                unfilter(raw, 0, stride, height, bpp);
                for (int y = 0; y < height; y++)
                    convertRow(raw, y * (stride + 1) + 1, width, out, y, 0, 1);
            } else {
                int[] sx = {0, 4, 0, 2, 0, 1, 0}, sy = {0, 0, 4, 0, 2, 0, 1};
                int[] dx = {8, 8, 4, 4, 2, 2, 1}, dy = {8, 8, 8, 4, 4, 2, 2};
                int off = 0;
                for (int p = 0; p < 7; p++) {
                    int pw = (width - sx[p] + dx[p] - 1) / dx[p];
                    int ph = (height - sy[p] + dy[p] - 1) / dy[p];
                    if (pw <= 0 || ph <= 0) continue;
                    int stride = (pw * bitsPerPixel + 7) / 8;
                    if (raw.length < off + (long) (stride + 1) * ph) throw new ImageException("PNG: not enough image data");
                    unfilter(raw, off, stride, ph, bpp);
                    for (int y = 0; y < ph; y++)
                        convertRow(raw, off + y * (stride + 1) + 1, pw, out, sy[p] + y * dy[p], sx[p], dx[p]);
                    off += (stride + 1) * ph;
                }
            }
            return new Image(width, height, out);
        }

        boolean validDepth() {
            switch (colorType) {
                case 0: return depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16;
                case 3: return depth == 1 || depth == 2 || depth == 4 || depth == 8;
                case 2: case 4: case 6: return depth == 8 || depth == 16;
                default: return false;
            }
        }

        int channels() {
            switch (colorType) {
                case 2: return 3;
                case 4: return 2;
                case 6: return 4;
                default: return 1;
            }
        }

        static byte[] inflate(byte[] z) {
            Inflater inf = new Inflater();
            inf.setInput(z);
            ByteArrayOutputStream out = new ByteArrayOutputStream(Math.max(64, z.length * 4));
            byte[] buf = new byte[65536];
            try {
                while (!inf.finished()) {
                    int n = inf.inflate(buf);
                    if (n == 0 && (inf.needsInput() || inf.needsDictionary())) break;
                    out.write(buf, 0, n);
                }
            } catch (DataFormatException e) {
                throw new ImageException("PNG: bad compressed data");
            } finally {
                inf.end();
            }
            return out.toByteArray();
        }

        // Undoes the scanline filters in place; each row is a filter byte and stride bytes.
        static void unfilter(byte[] r, int off, int stride, int rows, int bpp) {
            for (int y = 0; y < rows; y++) {
                int row = off + y * (stride + 1);
                int f = r[row] & 0xFF;
                int cur = row + 1, prev = row - stride;   // prev row's data start
                boolean first = y == 0;
                switch (f) {
                    case 0: break;
                    case 1:
                        for (int i = bpp; i < stride; i++) r[cur + i] += r[cur + i - bpp];
                        break;
                    case 2:
                        if (!first) for (int i = 0; i < stride; i++) r[cur + i] += r[prev + i];
                        break;
                    case 3:
                        for (int i = 0; i < stride; i++) {
                            int a = i >= bpp ? r[cur + i - bpp] & 0xFF : 0;
                            int b = first ? 0 : r[prev + i] & 0xFF;
                            r[cur + i] += (byte) ((a + b) >> 1);
                        }
                        break;
                    case 4:
                        for (int i = 0; i < stride; i++) {
                            int a = i >= bpp ? r[cur + i - bpp] & 0xFF : 0;
                            int b = first ? 0 : r[prev + i] & 0xFF;
                            int c = (i >= bpp && !first) ? r[prev + i - bpp] & 0xFF : 0;
                            int p = a + b - c;
                            int pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
                            int pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
                            r[cur + i] += (byte) pr;
                        }
                        break;
                    default:
                        throw new ImageException("PNG: bad filter type");
                }
            }
        }

        // The n-th sample of a row at full precision.
        int sample(byte[] r, int start, int n) {
            switch (depth) {
                case 16: return ((r[start + 2 * n] & 0xFF) << 8) | (r[start + 2 * n + 1] & 0xFF);
                case 8: return r[start + n] & 0xFF;
                default: {
                    int bit = n * depth;
                    int b = r[start + (bit >> 3)] & 0xFF;
                    return (b >> (8 - depth - (bit & 7))) & ((1 << depth) - 1);
                }
            }
        }

        int to8(int v) {
            switch (depth) {
                case 16: return v >> 8;
                case 8: return v;
                default: return v * 255 / ((1 << depth) - 1);
            }
        }

        void convertRow(byte[] r, int start, int n, byte[] out, int y, int x0, int dx) {
            for (int i = 0; i < n; i++) {
                int o = (y * width + x0 + i * dx) * 4;
                int R, G, B, A = 255;
                switch (colorType) {
                    case 0: {
                        int g = sample(r, start, i);
                        R = G = B = to8(g);
                        if (transparent != null && g == transparent[0]) A = 0;
                        break;
                    }
                    case 2: {
                        int r0 = sample(r, start, 3 * i), g0 = sample(r, start, 3 * i + 1), b0 = sample(r, start, 3 * i + 2);
                        R = to8(r0); G = to8(g0); B = to8(b0);
                        if (transparent != null && r0 == transparent[0] && g0 == transparent[1] && b0 == transparent[2]) A = 0;
                        break;
                    }
                    case 3: {
                        int idx = sample(r, start, i);
                        if (3 * idx + 2 >= palette.length) { R = G = B = 0; }
                        else { R = palette[3 * idx] & 0xFF; G = palette[3 * idx + 1] & 0xFF; B = palette[3 * idx + 2] & 0xFF; }
                        if (paletteAlpha != null && idx < paletteAlpha.length) A = paletteAlpha[idx] & 0xFF;
                        break;
                    }
                    case 4:
                        R = G = B = to8(sample(r, start, 2 * i));
                        A = to8(sample(r, start, 2 * i + 1));
                        break;
                    default:
                        R = to8(sample(r, start, 4 * i)); G = to8(sample(r, start, 4 * i + 1));
                        B = to8(sample(r, start, 4 * i + 2)); A = to8(sample(r, start, 4 * i + 3));
                        break;
                }
                out[o] = (byte) R; out[o + 1] = (byte) G; out[o + 2] = (byte) B; out[o + 3] = (byte) A;
            }
        }
    }

    // --- JPEG decoding -------------------------------------------------------

    static final int[] ZIGZAG = {
        0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
        12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
        35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
        58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
    };

    // IDCT basis: C(u) cos((2x + 1) u pi / 16) / 2
    static final float[] IDCT = new float[64];
    static {
        for (int x = 0; x < 8; x++)
            for (int u = 0; u < 8; u++)
                IDCT[x * 8 + u] = (float) ((u == 0 ? Math.sqrt(0.5) : 1.0) * Math.cos((2 * x + 1) * u * Math.PI / 16) / 2);
    }

    static final class Huffman {
        final int[] maxCode = new int[18];
        final int[] valPtr = new int[17];
        final int[] minCode = new int[17];
        final int[] values;
        // fast lookup of codes up to 9 bits: (length << 8) | value, 0 if longer
        final int[] fast = new int[512];

        Huffman(int[] counts, int[] values) {
            this.values = values;
            int code = 0, k = 0;
            for (int len = 1; len <= 16; len++) {
                valPtr[len] = k;
                minCode[len] = code;
                code += counts[len - 1];
                k += counts[len - 1];
                maxCode[len] = counts[len - 1] > 0 ? code - 1 : -1;
                code <<= 1;
            }
            maxCode[17] = Integer.MAX_VALUE;
            k = 0; code = 0;
            for (int len = 1; len <= 16; len++) {
                for (int i = 0; i < counts[len - 1]; i++, k++, code++) {
                    if (len <= 9) {
                        int shift = 9 - len;
                        for (int j = 0; j < (1 << shift); j++)
                            fast[(code << shift) | j] = (len << 8) | values[k];
                    }
                }
                code <<= 1;
            }
        }
    }

    static final class Component {
        int id, h, v, tq;
        int bw, bh;            // blocks per line / column, padded to whole MCUs
        int cw, ch;            // blocks actually covering the component (non-interleaved scans)
        short[] coef;          // bw * bh * 64, natural order
        int dcPred;
        Huffman dc, ac;
        byte[] plane;          // bw*8 x bh*8 samples after IDCT
    }

    static final class Jpeg {
        final byte[] d;
        final long maxPixels;
        int pos;
        final int[][] qt = new int[4][];
        final Huffman[] dcTables = new Huffman[4], acTables = new Huffman[4];
        Component[] comps;
        int width, height, hmax, vmax, mcusX, mcusY;
        boolean progressive;
        int restartInterval;
        int adobe = -1;        // Adobe APP14 transform, -1 if none
        boolean jfif;
        // bit reader
        int bitBuf, bitCnt;
        boolean hitMarker;
        int eobrun;

        Jpeg(byte[] d, long maxPixels) { this.d = d; this.maxPixels = maxPixels; }

        int u16(int i) {
            if (i + 1 >= d.length) throw new ImageException("JPEG: truncated");
            return ((d[i] & 0xFF) << 8) | (d[i + 1] & 0xFF);
        }

        Image decode() {
            pos = 2;
            boolean frame = false;
            while (true) {
                // find the next marker
                while (pos < d.length && (d[pos] & 0xFF) != 0xFF) pos++;
                while (pos < d.length && (d[pos] & 0xFF) == 0xFF) pos++;
                if (pos >= d.length) break;
                int m = d[pos++] & 0xFF;
                if (m == 0xD9) break;                                 // EOI
                if (m >= 0xD0 && m <= 0xD7) continue;                 // stray RST
                if (m == 0x01) continue;
                int len = u16(pos);
                int seg = pos + 2, end = pos + len;
                if (end > d.length) throw new ImageException("JPEG: truncated segment");
                switch (m) {
                    case 0xC0: case 0xC1: case 0xC2:
                        readFrame(seg, m == 0xC2);
                        frame = true;
                        pos = end;
                        break;
                    case 0xC4: readHuffman(seg, end); pos = end; break;
                    case 0xDB: readQuant(seg, end); pos = end; break;
                    case 0xDD: restartInterval = u16(seg); pos = end; break;
                    case 0xDA:
                        if (!frame) throw new ImageException("JPEG: scan before frame");
                        pos = readScan(seg);
                        break;
                    case 0xEE:
                        if (len >= 12 && d[seg] == 'A' && d[seg + 1] == 'd' && d[seg + 2] == 'o' && d[seg + 3] == 'b' && d[seg + 4] == 'e')
                            adobe = d[seg + 11] & 0xFF;
                        pos = end;
                        break;
                    case 0xE0:
                        if (len >= 7 && d[seg] == 'J' && d[seg + 1] == 'F' && d[seg + 2] == 'I' && d[seg + 3] == 'F') jfif = true;
                        pos = end;
                        break;
                    default:
                        if ((m >= 0xC3 && m <= 0xCF) && m != 0xC4 && m != 0xC8 && m != 0xCC)
                            throw new ImageException("JPEG: unsupported coding (lossless, hierarchical or arithmetic)");
                        pos = end;
                        break;
                }
            }
            if (!frame) throw new ImageException("JPEG: no frame");
            return output();
        }

        void readFrame(int p, boolean prog) {
            progressive = prog;
            if ((d[p] & 0xFF) != 8) throw new ImageException("JPEG: only 8-bit samples are supported");
            height = u16(p + 1);
            width = u16(p + 3);
            int n = d[p + 5] & 0xFF;
            if (height == 0) throw new ImageException("JPEG: height defined by DNL is not supported");
            checkSize(width, height, maxPixels);
            if (n != 1 && n != 3 && n != 4) throw new ImageException("JPEG: unsupported number of components");
            comps = new Component[n];
            hmax = vmax = 1;
            for (int i = 0; i < n; i++) {
                Component c = new Component();
                int q = p + 6 + i * 3;
                c.id = d[q] & 0xFF;
                c.h = (d[q + 1] & 0xFF) >> 4;
                c.v = d[q + 1] & 0x0F;
                c.tq = d[q + 2] & 3;
                if (c.h < 1 || c.h > 4 || c.v < 1 || c.v > 4) throw new ImageException("JPEG: bad sampling factors");
                hmax = Math.max(hmax, c.h);
                vmax = Math.max(vmax, c.v);
                comps[i] = c;
            }
            mcusX = (width + 8 * hmax - 1) / (8 * hmax);
            mcusY = (height + 8 * vmax - 1) / (8 * vmax);
            for (Component c : comps) {
                c.bw = mcusX * c.h;
                c.bh = mcusY * c.v;
                c.cw = ((width * c.h + hmax - 1) / hmax + 7) / 8;
                c.ch = ((height * c.v + vmax - 1) / vmax + 7) / 8;
                c.coef = new short[c.bw * c.bh * 64];
            }
        }

        void readHuffman(int p, int end) {
            while (p < end) {
                int tc = (d[p] & 0xFF) >> 4, th = d[p] & 0x0F;
                if (th > 3 || tc > 1) throw new ImageException("JPEG: bad Huffman table");
                int[] counts = new int[16];
                int total = 0;
                for (int i = 0; i < 16; i++) { counts[i] = d[p + 1 + i] & 0xFF; total += counts[i]; }
                if (p + 17 + total > end) throw new ImageException("JPEG: bad Huffman table");
                int[] vals = new int[total];
                for (int i = 0; i < total; i++) vals[i] = d[p + 17 + i] & 0xFF;
                Huffman h = new Huffman(counts, vals);
                if (tc == 0) dcTables[th] = h; else acTables[th] = h;
                p += 17 + total;
            }
        }

        void readQuant(int p, int end) {
            while (p < end) {
                int pq = (d[p] & 0xFF) >> 4, tq = d[p] & 0x0F;
                if (tq > 3) throw new ImageException("JPEG: bad quantization table");
                int[] t = new int[64];
                p++;
                for (int i = 0; i < 64; i++) {
                    if (pq == 0) t[ZIGZAG[i]] = d[p++] & 0xFF;
                    else { t[ZIGZAG[i]] = u16(p); p += 2; }
                }
                qt[tq] = t;
            }
        }

        // --- entropy-coded data ---

        int readBit() {
            if (bitCnt == 0) fill();
            bitCnt--;
            return (bitBuf >>> bitCnt) & 1;
        }

        void fill() {
            int b = 0;
            if (!hitMarker && pos >= d.length) throw new ImageException("JPEG: truncated data");
            if (!hitMarker && pos < d.length) {
                b = d[pos] & 0xFF;
                if (b == 0xFF) {
                    int next = pos + 1 < d.length ? d[pos + 1] & 0xFF : 0;
                    if (next == 0) { pos += 2; }
                    else { hitMarker = true; b = 0; }
                } else {
                    pos++;
                }
            }
            bitBuf = ((bitBuf << 8) | b) & 0xFFFF;
            bitCnt += 8;
        }

        int receive(int n) {
            int v = 0;
            for (int i = 0; i < n; i++) v = (v << 1) | readBit();
            return v;
        }

        int extend(int v, int n) {
            return n == 0 ? 0 : (v < (1 << (n - 1)) ? v - (1 << n) + 1 : v);
        }

        int decodeHuff(Huffman h) {
            if (h == null) throw new ImageException("JPEG: missing Huffman table");
            if (bitCnt < 9) { fill(); if (bitCnt < 9) fill(); }
            int peek = (bitBuf >>> (bitCnt - 9)) & 0x1FF;
            int f = h.fast[peek];
            if (f != 0) {
                bitCnt -= f >> 8;
                return f & 0xFF;
            }
            int code = 0;
            for (int len = 1; len <= 16; len++) {
                code = (code << 1) | readBit();
                if (h.maxCode[len] >= 0 && code <= h.maxCode[len] && code >= h.minCode[len])
                    return h.values[h.valPtr[len] + code - h.minCode[len]];
            }
            throw new ImageException("JPEG: bad Huffman code");
        }

        void resetBits() { bitBuf = 0; bitCnt = 0; hitMarker = false; }

        // Reads a scan and returns the position after its entropy-coded data.
        int readScan(int p) {
            int ns = d[p] & 0xFF;
            Component[] sc = new Component[ns];
            for (int i = 0; i < ns; i++) {
                int cid = d[p + 1 + 2 * i] & 0xFF;
                int t = d[p + 2 + 2 * i] & 0xFF;
                Component c = null;
                for (Component x : comps) if (x.id == cid) c = x;
                if (c == null) throw new ImageException("JPEG: scan names an unknown component");
                c.dc = dcTables[t >> 4];
                c.ac = acTables[t & 15];
                sc[i] = c;
            }
            int q = p + 1 + 2 * ns;
            int ss = d[q] & 0xFF, se = d[q + 1] & 0xFF, ah = (d[q + 2] & 0xFF) >> 4, al = d[q + 2] & 0x0F;
            pos = q + 3;
            resetBits();
            eobrun = 0;
            for (Component c : sc) c.dcPred = 0;
            int mcus = ns == 1 ? sc[0].cw * sc[0].ch : mcusX * mcusY;
            int sinceRestart = 0;
            for (int n = 0; n < mcus; n++) {
                if (restartInterval > 0 && sinceRestart == restartInterval) {
                    // expect RSTn: realign, skip the marker, reset predictions
                    resetBits();
                    while (pos < d.length && !((d[pos] & 0xFF) == 0xFF && pos + 1 < d.length
                            && (d[pos + 1] & 0xFF) >= 0xD0 && (d[pos + 1] & 0xFF) <= 0xD7)) pos++;
                    if (pos < d.length) pos += 2;
                    for (Component c : sc) c.dcPred = 0;
                    eobrun = 0;
                    sinceRestart = 0;
                }
                if (ns == 1) {
                    Component c = sc[0];
                    int bx = n % c.cw, by = n / c.cw;
                    decodeBlock(c, (by * c.bw + bx) * 64, ss, se, ah, al);
                } else {
                    int mx = n % mcusX, my = n / mcusX;
                    for (Component c : sc)
                        for (int v = 0; v < c.v; v++)
                            for (int h = 0; h < c.h; h++) {
                                int bx = mx * c.h + h, by = my * c.v + v;
                                decodeBlock(c, (by * c.bw + bx) * 64, ss, se, ah, al);
                            }
                }
                sinceRestart++;
            }
            // skip to the next marker (past any padding)
            while (pos < d.length) {
                if ((d[pos] & 0xFF) == 0xFF && pos + 1 < d.length) {
                    int nx = d[pos + 1] & 0xFF;
                    if (nx != 0 && !(nx >= 0xD0 && nx <= 0xD7)) break;
                }
                pos++;
            }
            return pos;
        }

        void decodeBlock(Component c, int off, int ss, int se, int ah, int al) {
            short[] z = c.coef;
            if (!progressive) {
                int t = decodeHuff(c.dc);
                int diff = t == 0 ? 0 : extend(receive(t), t);
                c.dcPred += diff;
                z[off] = (short) c.dcPred;
                for (int k = 1; k < 64; ) {
                    int rs = decodeHuff(c.ac);
                    int r = rs >> 4, s = rs & 15;
                    if (s == 0) {
                        if (r == 15) { k += 16; continue; }
                        break;
                    }
                    k += r;
                    if (k > 63) break;
                    z[off + ZIGZAG[k]] = (short) extend(receive(s), s);
                    k++;
                }
                return;
            }
            if (ss == 0) {
                // DC scans
                if (ah == 0) {
                    int t = decodeHuff(c.dc);
                    int diff = t == 0 ? 0 : extend(receive(t), t);
                    c.dcPred += diff;
                    z[off] = (short) (c.dcPred << al);
                } else if (readBit() != 0) {
                    z[off] |= (short) (1 << al);
                }
                return;
            }
            if (ah == 0) {
                // AC first pass
                if (eobrun > 0) { eobrun--; return; }
                for (int k = ss; k <= se; ) {
                    int rs = decodeHuff(c.ac);
                    int r = rs >> 4, s = rs & 15;
                    if (s == 0) {
                        if (r < 15) {
                            eobrun = (1 << r) - 1;
                            if (r > 0) eobrun += receive(r);
                            break;
                        }
                        k += 16;
                        continue;
                    }
                    k += r;
                    if (k > 63) break;
                    z[off + ZIGZAG[k]] = (short) (extend(receive(s), s) * (1 << al));
                    k++;
                }
                return;
            }
            refineAc(c, off, ss, se, al);
        }

        void refineAc(Component c, int off, int ss, int se, int al) {
            short[] z = c.coef;
            int p1 = 1 << al, m1 = -1 << al;
            int k = ss;
            if (eobrun <= 0) {
                for (; k <= se; ) {
                    int rs = decodeHuff(c.ac);
                    int r = rs >> 4, s = rs & 15;
                    int value = 0;
                    if (s == 0) {
                        if (r < 15) {
                            eobrun = (1 << r);
                            if (r > 0) eobrun += receive(r);
                            break;
                        }
                    } else {
                        value = readBit() != 0 ? p1 : m1;
                    }
                    while (k <= se) {
                        int zk = off + ZIGZAG[k];
                        if (z[zk] != 0) {
                            if (readBit() != 0 && (z[zk] & p1) == 0)
                                z[zk] += (short) (z[zk] >= 0 ? p1 : m1);
                        } else {
                            if (r == 0) {
                                if (value != 0) z[zk] = (short) value;
                                k++;
                                break;
                            }
                            r--;
                        }
                        k++;
                    }
                }
            }
            if (eobrun > 0) {
                for (; k <= se; k++) {
                    int zk = off + ZIGZAG[k];
                    if (z[zk] != 0 && readBit() != 0 && (z[zk] & p1) == 0)
                        z[zk] += (short) (z[zk] >= 0 ? p1 : m1);
                }
                eobrun--;
            }
        }

        // --- output ---

        void idctPlanes() {
            float[] tmp = new float[64];
            for (Component c : comps) {
                int[] q = qt[c.tq];
                if (q == null) throw new ImageException("JPEG: missing quantization table");
                int stride = c.bw * 8;
                c.plane = new byte[stride * c.bh * 8];
                for (int by = 0; by < c.bh; by++)
                    for (int bx = 0; bx < c.bw; bx++) {
                        int off = (by * c.bw + bx) * 64;
                        // rows: tmp[y][x] = sum_u coef[y][u] q IDCT[x][u]
                        for (int y = 0; y < 8; y++) {
                            int r = off + y * 8;
                            boolean zeroAc = true;
                            for (int u = 1; u < 8; u++) if (c.coef[r + u] != 0) { zeroAc = false; break; }
                            if (zeroAc) {
                                float dc = c.coef[r] * q[y * 8] * IDCT[0];
                                for (int x = 0; x < 8; x++) tmp[y * 8 + x] = dc;
                                continue;
                            }
                            for (int x = 0; x < 8; x++) {
                                float s = 0;
                                for (int u = 0; u < 8; u++) s += c.coef[r + u] * q[y * 8 + u] * IDCT[x * 8 + u];
                                tmp[y * 8 + x] = s;
                            }
                        }
                        // columns
                        int base = by * 8 * stride + bx * 8;
                        for (int x = 0; x < 8; x++)
                            for (int y = 0; y < 8; y++) {
                                float s = 0;
                                for (int v = 0; v < 8; v++) s += tmp[v * 8 + x] * IDCT[y * 8 + v];
                                int val = Math.round(s + 128);
                                c.plane[base + y * stride + x] = (byte) (val < 0 ? 0 : (val > 255 ? 255 : val));
                            }
                    }
                c.coef = null;
            }
        }

        static int clamp(int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }

        // For each of n output positions: the two component samples around
        // it and the weight of the second; f samples per fmax output pixels,
        // m samples in all.
        static void axis(int n, int f, int fmax, int m, int[] i0, int[] i1, float[] w) {
            for (int x = 0; x < n; x++) {
                if (f == fmax) { i0[x] = i1[x] = x; w[x] = 0; continue; }
                float c = (x + 0.5f) * f / fmax - 0.5f;
                int lo = (int) Math.floor(c);
                float t = c - lo;
                int a = Math.max(0, Math.min(m - 1, lo)), b = Math.max(0, Math.min(m - 1, lo + 1));
                i0[x] = a; i1[x] = b; w[x] = t;
            }
        }

        Image output() {
            idctPlanes();
            byte[] out = new byte[width * height * 4];
            int n = comps.length;
            boolean rgb = n == 3 && (adobe == 0 || (!jfif && adobe < 0 && comps[0].id == 'R' && comps[1].id == 'G' && comps[2].id == 'B'));
            int[] sample = new int[4];
            // Subsampled components are interpolated linearly between sample
            // centres (for 2:1, libjpeg's "fancy" 3/4 + 1/4 weights).
            int[][] x0 = new int[n][], x1 = new int[n][], y0 = new int[n][], y1 = new int[n][];
            float[][] fx = new float[n][], fy = new float[n][];
            for (int i = 0; i < n; i++) {
                Component c = comps[i];
                int cw = (width * c.h + hmax - 1) / hmax, ch = (height * c.v + vmax - 1) / vmax;
                x0[i] = new int[width]; x1[i] = new int[width]; fx[i] = new float[width];
                y0[i] = new int[height]; y1[i] = new int[height]; fy[i] = new float[height];
                axis(width, c.h, hmax, cw, x0[i], x1[i], fx[i]);
                axis(height, c.v, vmax, ch, y0[i], y1[i], fy[i]);
            }
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    for (int i = 0; i < n; i++) {
                        Component c = comps[i];
                        int stride = c.bw * 8;
                        byte[] pl = c.plane;
                        if (c.h == hmax && c.v == vmax) {
                            sample[i] = pl[y * stride + x] & 0xFF;
                        } else {
                            int r0 = y0[i][y] * stride, r1 = y1[i][y] * stride;
                            int a = x0[i][x], b = x1[i][x];
                            float wx = fx[i][x], wy = fy[i][y];
                            float top = (pl[r0 + a] & 0xFF) * (1 - wx) + (pl[r0 + b] & 0xFF) * wx;
                            float bot = (pl[r1 + a] & 0xFF) * (1 - wx) + (pl[r1 + b] & 0xFF) * wx;
                            sample[i] = Math.round(top * (1 - wy) + bot * wy);
                        }
                    }
                    int o = (y * width + x) * 4;
                    int R, G, B;
                    if (n == 1) {
                        R = G = B = sample[0];
                    } else if (n == 3 && rgb) {
                        R = sample[0]; G = sample[1]; B = sample[2];
                    } else {
                        if (n == 3 || adobe == 2) {
                            float Y = sample[0], cb = sample[1] - 128, cr = sample[2] - 128;
                            R = clamp(Math.round(Y + 1.402f * cr));
                            G = clamp(Math.round(Y - 0.344136f * cb - 0.714136f * cr));
                            B = clamp(Math.round(Y + 1.772f * cb));
                        } else {
                            R = sample[0]; G = sample[1]; B = sample[2];
                        }
                        if (n == 4) {
                            // Adobe stores CMYK inverted: the samples are 255 - C, ...
                            int k = sample[3];
                            if (adobe >= 0) {
                                R = R * k / 255; G = G * k / 255; B = B * k / 255;
                            } else {
                                R = (255 - R) * (255 - k) / 255; G = (255 - G) * (255 - k) / 255; B = (255 - B) * (255 - k) / 255;
                            }
                        }
                    }
                    out[o] = (byte) R; out[o + 1] = (byte) G; out[o + 2] = (byte) B; out[o + 3] = (byte) 255;
                }
            }
            return new Image(width, height, out);
        }
    }

    // --- resizing ------------------------------------------------------------

    /**
     * Resizes straight RGBA pixels to nw x nh. method 0: box (the area each
     * target pixel covers, averaged), 1: bilinear (a triangle filter, widened
     * when shrinking so that every source pixel counts). Colours are averaged
     * premultiplied by alpha, so transparent pixels don't bleed.
     */
    public static byte[] resize(byte[] src, int w, int h, int nw, int nh, int method) {
        if (w <= 0 || h <= 0 || nw <= 0 || nh <= 0 || src.length < (long) w * h * 4)
            throw new ImageException("bad image size");
        // horizontal: w x h -> nw x h, premultiplied
        Weights wx = weights(w, nw, method);
        float[] mid = new float[nw * h * 4];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < nw; x++) {
                float r = 0, g = 0, b = 0, a = 0;
                int first = wx.first[x];
                for (int k = 0; k < wx.count[x]; k++) {
                    int s = (y * w + first + k) * 4;
                    float alpha = src[s + 3] & 0xFF;
                    float f = wx.w[x][k];
                    float fa = f * alpha / 255f;
                    r += (src[s] & 0xFF) * fa; g += (src[s + 1] & 0xFF) * fa; b += (src[s + 2] & 0xFF) * fa;
                    a += alpha * f;
                }
                int o = (y * nw + x) * 4;
                mid[o] = r; mid[o + 1] = g; mid[o + 2] = b; mid[o + 3] = a;
            }
        // vertical: nw x h -> nw x nh
        Weights wy = weights(h, nh, method);
        byte[] out = new byte[nw * nh * 4];
        for (int y = 0; y < nh; y++)
            for (int x = 0; x < nw; x++) {
                float r = 0, g = 0, b = 0, a = 0;
                int first = wy.first[y];
                for (int k = 0; k < wy.count[y]; k++) {
                    float f = wy.w[y][k];
                    int s = ((first + k) * nw + x) * 4;
                    r += mid[s] * f; g += mid[s + 1] * f; b += mid[s + 2] * f; a += mid[s + 3] * f;
                }
                int o = (y * nw + x) * 4;
                int A = Math.round(a);
                A = A < 0 ? 0 : (A > 255 ? 255 : A);
                if (A == 0) {
                    out[o] = out[o + 1] = out[o + 2] = out[o + 3] = 0;
                } else {
                    float inv = 1f / (a / 255f);
                    out[o] = (byte) Jpeg.clamp(Math.round(r * inv));
                    out[o + 1] = (byte) Jpeg.clamp(Math.round(g * inv));
                    out[o + 2] = (byte) Jpeg.clamp(Math.round(b * inv));
                    out[o + 3] = (byte) A;
                }
            }
        return out;
    }

    static final class Weights {
        int[] first, count;
        float[][] w;
    }

    static Weights weights(int n, int nn, int method) {
        Weights ws = new Weights();
        ws.first = new int[nn]; ws.count = new int[nn]; ws.w = new float[nn][];
        double scale = (double) n / nn;          // source pixels per target pixel
        for (int i = 0; i < nn; i++) {
            double center = (i + 0.5) * scale;   // in source coordinates
            int lo, hi;
            double[] tmp;
            if (method == 0) {
                // box: overlap of [i*scale, (i+1)*scale) with each source pixel [j, j+1)
                double a = i * scale, b = (i + 1) * scale;
                if (scale < 1) { a = center - 0.5; b = center + 0.5; }   // enlarging: nearest pixel's area
                lo = (int) Math.floor(a); hi = (int) Math.ceil(b) - 1;
                lo = Math.max(lo, 0); hi = Math.min(hi, n - 1);
                if (hi < lo) hi = lo;
                tmp = new double[hi - lo + 1];
                for (int j = lo; j <= hi; j++) tmp[j - lo] = Math.max(0, Math.min(b, j + 1) - Math.max(a, j));
            } else {
                double support = Math.max(1.0, scale);
                lo = (int) Math.floor(center - support); hi = (int) Math.ceil(center + support);
                lo = Math.max(lo, 0); hi = Math.min(hi, n - 1);
                tmp = new double[hi - lo + 1];
                for (int j = lo; j <= hi; j++) {
                    double t = Math.abs((j + 0.5 - center) / support);
                    tmp[j - lo] = t < 1 ? 1 - t : 0;
                }
            }
            double sum = 0;
            for (double t : tmp) sum += t;
            if (sum <= 0) {                       // degenerate: take the nearest pixel
                int j = Math.min(n - 1, Math.max(0, (int) center));
                lo = j; tmp = new double[] {1}; sum = 1;
            }
            ws.first[i] = lo;
            ws.count[i] = tmp.length;
            ws.w[i] = new float[tmp.length];
            for (int k = 0; k < tmp.length; k++) ws.w[i][k] = (float) (tmp[k] / sum);
        }
        return ws;
    }

    // --- orientation -----------------------------------------------------------

    /**
     * Applies EXIF orientation o (1-8) to w x h RGBA pixels: the result is how
     * the image is meant to be shown; for 5-8 it is h x w.
     */
    public static byte[] orient(byte[] src, int w, int h, int o) {
        if (o < 1 || o > 8) throw new ImageException("bad orientation (1 to 8)");
        boolean swap = o >= 5;
        int ow = swap ? h : w, oh = swap ? w : h;
        byte[] out = new byte[src.length];
        for (int y = 0; y < oh; y++)
            for (int x = 0; x < ow; x++) {
                int sx, sy;
                switch (o) {
                    case 2: sx = w - 1 - x; sy = y; break;
                    case 3: sx = w - 1 - x; sy = h - 1 - y; break;
                    case 4: sx = x; sy = h - 1 - y; break;
                    case 5: sx = y; sy = x; break;
                    case 6: sx = y; sy = h - 1 - x; break;
                    case 7: sx = w - 1 - y; sy = h - 1 - x; break;
                    case 8: sx = w - 1 - y; sy = x; break;
                    default: sx = x; sy = y; break;
                }
                System.arraycopy(src, (sy * w + sx) * 4, out, (y * ow + x) * 4, 4);
            }
        return out;
    }

    // --- JPEG encoding -----------------------------------------------------------

    static final int[] STD_LUMA_Q = {
        16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55,
        14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62,
        18, 22, 37, 56, 68, 109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92,
        49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99
    };
    static final int[] STD_CHROMA_Q = {
        17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99,
        24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99
    };
    // Annex K Huffman tables: counts per length 1..16, then values
    static final int[] DC_LUMA_COUNTS = {0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0};
    static final int[] DC_LUMA_VALS = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    static final int[] DC_CHROMA_COUNTS = {0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0};
    static final int[] DC_CHROMA_VALS = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    static final int[] AC_LUMA_COUNTS = {0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d};
    static final int[] AC_LUMA_VALS = {
        0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
        0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0,
        0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
        0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
        0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
        0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
        0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
        0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5,
        0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
        0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
        0xf9, 0xfa
    };
    static final int[] AC_CHROMA_COUNTS = {0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77};
    static final int[] AC_CHROMA_VALS = {
        0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
        0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0,
        0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26,
        0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
        0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
        0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
        0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,
        0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3,
        0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
        0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,
        0xf9, 0xfa
    };

    static final class BitWriter {
        final ByteArrayOutputStream out;
        int buf, cnt;
        BitWriter(ByteArrayOutputStream out) { this.out = out; }
        void write(int code, int len) {
            for (int i = len - 1; i >= 0; i--) {
                buf = (buf << 1) | ((code >>> i) & 1);
                if (++cnt == 8) {
                    out.write(buf);
                    if (buf == 0xFF) out.write(0);
                    buf = 0; cnt = 0;
                }
            }
        }
        void flush() {
            while (cnt != 0) write(1, 1);   // pad with ones
        }
    }

    // code/length per symbol from counts and values
    static int[][] huffCodes(int[] counts, int[] vals) {
        int[] code = new int[256], size = new int[256];
        int c = 0, k = 0;
        for (int len = 1; len <= 16; len++) {
            for (int i = 0; i < counts[len - 1]; i++, k++) {
                code[vals[k]] = c++;
                size[vals[k]] = len;
            }
            c <<= 1;
        }
        return new int[][] {code, size};
    }

    static int[] scaledQuant(int[] std, int quality) {
        int q = Math.max(1, Math.min(100, quality));
        int scale = q < 50 ? 5000 / q : 200 - 2 * q;
        int[] t = new int[64];
        for (int i = 0; i < 64; i++) t[i] = Math.max(1, Math.min(255, (std[i] * scale + 50) / 100));
        return t;
    }

    // DCT basis for the forward transform (same as IDCT's)
    /**
     * Baseline JPEG (YCbCr 4:2:0, quality 1-100, standard tables) of w x h
     * RGBA pixels, alpha composited over white.
     */
    public static byte[] encodeJpeg(byte[] rgba, int w, int h, int quality) {
        if (w <= 0 || h <= 0 || w > 65535 || h > 65535) throw new ImageException("JPEG: bad image size");
        int[] ql = scaledQuant(STD_LUMA_Q, quality), qc = scaledQuant(STD_CHROMA_Q, quality);
        ByteArrayOutputStream out = new ByteArrayOutputStream(w * h / 4 + 1024);
        int[] app0 = {0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 'J', 'F', 'I', 'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0};
        for (int b : app0) out.write(b);
        for (int t = 0; t < 2; t++) {
            int[] q = t == 0 ? ql : qc;
            out.write(0xFF); out.write(0xDB); out.write(0); out.write(67); out.write(t);
            for (int i = 0; i < 64; i++) out.write(q[ZIGZAG[i]]);
        }
        int[] sof = {0xFF, 0xC0, 0, 17, 8, h >> 8, h & 0xFF, w >> 8, w & 0xFF, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1};
        for (int b : sof) out.write(b);
        writeDht(out, 0x00, DC_LUMA_COUNTS, DC_LUMA_VALS);
        writeDht(out, 0x10, AC_LUMA_COUNTS, AC_LUMA_VALS);
        writeDht(out, 0x01, DC_CHROMA_COUNTS, DC_CHROMA_VALS);
        writeDht(out, 0x11, AC_CHROMA_COUNTS, AC_CHROMA_VALS);
        int[] sos = {0xFF, 0xDA, 0, 12, 3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0};
        for (int b : sos) out.write(b);

        // planes: Y full size, Cb/Cr averaged over 2 x 2, all padded to 16
        int pw = (w + 15) / 16 * 16, ph = (h + 15) / 16 * 16;
        float[] Y = new float[pw * ph], Cb = new float[pw * ph / 4], Cr = new float[pw * ph / 4];
        float[] cbFull = new float[pw * ph], crFull = new float[pw * ph];
        for (int y = 0; y < ph; y++)
            for (int x = 0; x < pw; x++) {
                int s = (Math.min(y, h - 1) * w + Math.min(x, w - 1)) * 4;
                float a = (rgba[s + 3] & 0xFF) / 255f;
                float r = (rgba[s] & 0xFF) * a + 255 * (1 - a);
                float g = (rgba[s + 1] & 0xFF) * a + 255 * (1 - a);
                float b = (rgba[s + 2] & 0xFF) * a + 255 * (1 - a);
                int i = y * pw + x;
                Y[i] = 0.299f * r + 0.587f * g + 0.114f * b - 128;
                cbFull[i] = -0.168736f * r - 0.331264f * g + 0.5f * b;
                crFull[i] = 0.5f * r - 0.418688f * g - 0.081312f * b;
            }
        int cw = pw / 2;
        for (int y = 0; y < ph / 2; y++)
            for (int x = 0; x < cw; x++) {
                int i = 2 * y * pw + 2 * x;
                Cb[y * cw + x] = (cbFull[i] + cbFull[i + 1] + cbFull[i + pw] + cbFull[i + pw + 1]) / 4;
                Cr[y * cw + x] = (crFull[i] + crFull[i + 1] + crFull[i + pw] + crFull[i + pw + 1]) / 4;
            }
        int[][] dcl = huffCodes(DC_LUMA_COUNTS, DC_LUMA_VALS), acl = huffCodes(AC_LUMA_COUNTS, AC_LUMA_VALS);
        int[][] dcc = huffCodes(DC_CHROMA_COUNTS, DC_CHROMA_VALS), acc = huffCodes(AC_CHROMA_COUNTS, AC_CHROMA_VALS);
        BitWriter bw = new BitWriter(out);
        int[] pred = new int[3];
        float[] block = new float[64];
        for (int my = 0; my < ph / 16; my++)
            for (int mx = 0; mx < pw / 16; mx++) {
                for (int k = 0; k < 4; k++) {
                    int bx = mx * 16 + (k & 1) * 8, by = my * 16 + (k >> 1) * 8;
                    for (int y = 0; y < 8; y++)
                        for (int x = 0; x < 8; x++) block[y * 8 + x] = Y[(by + y) * pw + bx + x];
                    pred[0] = encodeBlock(bw, block, ql, pred[0], dcl, acl);
                }
                for (int c = 0; c < 2; c++) {
                    float[] plane = c == 0 ? Cb : Cr;
                    for (int y = 0; y < 8; y++)
                        for (int x = 0; x < 8; x++) block[y * 8 + x] = plane[(my * 8 + y) * cw + mx * 8 + x];
                    pred[c + 1] = encodeBlock(bw, block, qc, pred[c + 1], dcc, acc);
                }
            }
        bw.flush();
        out.write(0xFF); out.write(0xD9);
        return out.toByteArray();
    }

    static void writeDht(ByteArrayOutputStream out, int tcth, int[] counts, int[] vals) {
        int len = 2 + 1 + 16 + vals.length;
        out.write(0xFF); out.write(0xC4); out.write(len >> 8); out.write(len & 0xFF); out.write(tcth);
        for (int c : counts) out.write(c);
        for (int v : vals) out.write(v);
    }

    static int bitLength(int v) {
        v = Math.abs(v);
        int n = 0;
        while (v != 0) { n++; v >>= 1; }
        return n;
    }

    static int encodeBlock(BitWriter bw, float[] block, int[] q, int pred, int[][] dc, int[][] ac) {
        float[] tmp = new float[64];
        int[] coef = new int[64];
        // forward DCT: F(u,v) = sum_x sum_y f(x,y) basis(x,u) basis(y,v)
        for (int y = 0; y < 8; y++)
            for (int u = 0; u < 8; u++) {
                float s = 0;
                for (int x = 0; x < 8; x++) s += block[y * 8 + x] * IDCT[x * 8 + u];
                tmp[y * 8 + u] = s;
            }
        for (int u = 0; u < 8; u++)
            for (int v = 0; v < 8; v++) {
                float s = 0;
                for (int y = 0; y < 8; y++) s += tmp[y * 8 + u] * IDCT[y * 8 + v];
                coef[v * 8 + u] = Math.round(s / q[v * 8 + u]);
            }
        int diff = coef[0] - pred;
        int n = bitLength(diff);
        bw.write(dc[0][n], dc[1][n]);
        if (n > 0) bw.write(diff < 0 ? diff - 1 : diff, n);
        int run = 0;
        for (int k = 1; k < 64; k++) {
            int v = coef[ZIGZAG[k]];
            if (v == 0) { run++; continue; }
            while (run > 15) { bw.write(ac[0][0xF0], ac[1][0xF0]); run -= 16; }
            int s = bitLength(v);
            int sym = (run << 4) | s;
            bw.write(ac[0][sym], ac[1][sym]);
            bw.write(v < 0 ? v - 1 : v, s);
            run = 0;
        }
        if (run > 0) bw.write(ac[0][0], ac[1][0]);
        return coef[0];
    }
}
