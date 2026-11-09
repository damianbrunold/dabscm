package scheme.primitives;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.Socket;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.net.ssl.*;

// Shared TLS trust configuration for the HTTP client and verifying TLS sockets.
//
// The JDK only trusts its own cacerts file, while .NET (and browsers) on
// Windows use the Windows certificate store, which holds corporate root CAs
// deployed by group policy. To behave like the C# implementation, on Windows
// a certificate is accepted when either the JDK default trust store or one of
// the Windows root stores trusts it. Elsewhere the system CA bundle (the PEM
// file curl and OpenSSL use: SSL_CERT_FILE, else the distribution's bundle) is
// trusted besides the JDK store, so a CA added with update-ca-certificates
// works whichever JDK runs. Under WSL the Windows certificate stores are read
// as well (via powershell.exe, only when the other stores reject a chain), so
// corporate CAs deployed to the Windows host are trusted inside WSL too.
// Like Windows, intermediate certificates the server does not send are then
// looked up (Windows CA store under WSL) or downloaded from the CA issuer URL
// in the certificate's AIA extension. (The JDK's own AIA support is no use
// here: recent JDKs deny every URL not listed in com.sun.security.allowedAIALocations.)
//
// SCM_TLS_INSECURE=1 (or true/yes) disables certificate and host name
// verification for the HTTP client (insecure; for broken intranet setups only).
// SCM_TLS_DEBUG=1 prints the loaded trust stores and, on a failed check, the
// certificate chain sent by the server to stderr.
public final class TlsTrust {
    private TlsTrust() {}

    // Windows store types offered by the SunMSCAPI provider. The *-LOCALMACHINE
    // and *-CURRENTUSER variants only exist on newer JDKs; missing ones are skipped.
    private static final String[] WINDOWS_STORES = {
        "Windows-ROOT", "Windows-ROOT-LOCALMACHINE", "Windows-ROOT-CURRENTUSER"
    };

    private static volatile SSLContext verifyingContext;
    private static volatile HttpClient httpClient;
    private static volatile HttpClient httpClientNoRedirects;

    private static boolean envFlag(String name) {
        String v = System.getenv(name);
        if (v == null) return false;
        v = v.trim().toLowerCase();
        return v.equals("1") || v.equals("true") || v.equals("yes");
    }

    public static boolean insecureRequested() { return envFlag("SCM_TLS_INSECURE"); }

    static boolean debug() { return envFlag("SCM_TLS_DEBUG"); }

    static void debugLog(String msg) {
        if (debug()) System.err.println("scm-tls: " + msg);
    }

    // Text for a failed request: a refused connection carries no message,
    // only its type.
    public static String errorText(Exception e) {
        return e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
    }

    // The shared HttpClient used by http-get / http-post / http-send.
    public static HttpClient httpClient() throws Exception {
        HttpClient c = httpClient;
        if (c == null) {
            synchronized (TlsTrust.class) {
                c = httpClient;
                if (c == null) {
                    // Follow redirects like the C# client does, except
                    // HTTPS -> HTTP downgrades (Redirect.NORMAL).
                    c = HttpClient.newBuilder()
                        .sslContext(clientContext())
                        .followRedirects(HttpClient.Redirect.NORMAL)
                        .build();
                    httpClient = c;
                }
            }
        }
        return c;
    }

    // Shared HttpClient for requests made with follow-redirects? #f.
    public static HttpClient httpClientNoRedirects() throws Exception {
        HttpClient c = httpClientNoRedirects;
        if (c == null) {
            synchronized (TlsTrust.class) {
                c = httpClientNoRedirects;
                if (c == null) {
                    c = HttpClient.newBuilder()
                        .sslContext(clientContext())
                        .followRedirects(HttpClient.Redirect.NEVER)
                        .build();
                    httpClientNoRedirects = c;
                }
            }
        }
        return c;
    }

    private static boolean warnedInsecure;

    // Called under the TlsTrust lock.
    private static SSLContext clientContext() throws Exception {
        if (!insecureRequested()) return verifyingContext();
        if (!warnedInsecure) {
            warnedInsecure = true;
            System.err.println("warning: SCM_TLS_INSECURE is set, "
                + "HTTPS certificate verification is disabled");
        }
        return insecureContext();
    }

    // System CA bundles of common distributions (Debian/Ubuntu, Fedora/RHEL,
    // openSUSE, Alpine/macOS); the first existing one is used.
    private static final String[] SYSTEM_BUNDLES = {
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/ca-bundle.pem",
        "/etc/ssl/cert.pem"
    };

    // SSLContext trusting the JDK default store plus the platform's stores:
    // the Windows root stores on Windows, the system CA bundle elsewhere, and
    // under WSL (on demand) the Windows host's stores.
    public static SSLContext verifyingContext() throws Exception {
        SSLContext ctx = verifyingContext;
        if (ctx == null) {
            synchronized (TlsTrust.class) {
                ctx = verifyingContext;
                if (ctx == null) {
                    debugLog("java " + System.getProperty("java.version")
                        + " (" + System.getProperty("java.home") + "), os "
                        + System.getProperty("os.name"));
                    List<Named> tms = new ArrayList<>();
                    addTrustManagers(tms, "jdk-default", null);
                    if (isWindows()) {
                        for (String type : WINDOWS_STORES) {
                            try {
                                KeyStore ks = KeyStore.getInstance(type);
                                ks.load(null, null);
                                addTrustManagers(tms, type, ks);
                            } catch (Exception e) {
                                debugLog(type + " not available: " + e);
                            }
                        }
                    } else {
                        addSystemBundle(tms);
                    }
                    ctx = SSLContext.getInstance("TLS");
                    LateStores late = isWsl() ? TlsTrust::loadWslWindowsStores : null;
                    ctx.init(null, new TrustManager[]{ new CompositeTrustManager(tms, late) }, null);
                    verifyingContext = ctx;
                }
            }
        }
        return ctx;
    }

    public static SSLContext insecureContext() throws Exception {
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, new TrustManager[]{ new TrustAll() }, null);
        return ctx;
    }

    private static boolean isWindows() {
        return System.getProperty("os.name", "").toLowerCase().startsWith("windows");
    }

    // WSL: WSL_DISTRO_NAME / WSL_INTEROP are set in WSL sessions; the kernel
    // release names Microsoft also where they are not (e.g. under sudo).
    private static boolean isWsl() {
        if (isWindows()) return false;
        if (System.getenv("WSL_DISTRO_NAME") != null || System.getenv("WSL_INTEROP") != null) return true;
        try {
            String r = Files.readString(Path.of("/proc/sys/kernel/osrelease"));
            return r.toLowerCase().contains("microsoft");
        } catch (Exception e) {
            return false;
        }
    }

    private static void addSystemBundle(List<Named> tms) {
        String file = System.getenv("SSL_CERT_FILE");
        if (file == null || file.isBlank()) {
            file = null;
            for (String f : SYSTEM_BUNDLES) {
                if (new File(f).isFile()) { file = f; break; }
            }
        }
        if (file == null) {
            debugLog("no system CA bundle found");
            return;
        }
        try {
            List<X509Certificate> certs = parsePem(Files.readString(Path.of(file), StandardCharsets.ISO_8859_1));
            if (certs.isEmpty()) {
                debugLog("system CA bundle " + file + ": no certificates");
                return;
            }
            addTrustManagers(tms, "system " + file, keyStoreOf(certs));
        } catch (Exception e) {
            debugLog("cannot load system CA bundle " + file + ": " + e);
        }
    }

    private static final Pattern PEM_CERT = Pattern.compile(
        "-----BEGIN (?:TRUSTED )?CERTIFICATE-----([A-Za-z0-9+/=\\s]+?)-----END (?:TRUSTED )?CERTIFICATE-----");

    // Certificates of a PEM text; comments between blocks and unparsable
    // blocks are skipped.
    static List<X509Certificate> parsePem(String text) {
        List<X509Certificate> out = new ArrayList<>();
        Matcher m = PEM_CERT.matcher(text);
        while (m.find()) {
            X509Certificate c = parseDer(Base64.getMimeDecoder().decode(m.group(1)));
            if (c != null) out.add(c);
        }
        return out;
    }

    static X509Certificate parseDer(byte[] der) {
        try {
            return (X509Certificate) CertificateFactory.getInstance("X.509")
                .generateCertificate(new ByteArrayInputStream(der));
        } catch (Exception e) {
            return null;
        }
    }

    static KeyStore keyStoreOf(List<X509Certificate> certs) throws Exception {
        KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
        ks.load(null, null);
        int i = 0;
        for (X509Certificate c : certs) ks.setCertificateEntry("ca" + (i++), c);
        return ks;
    }

    // Stores loaded on first need; fills the trust managers and the pool of
    // intermediate certificates used to complete server chains.
    interface LateStores {
        void load(List<Named> trust, List<X509Certificate> intermediates);
    }

    // Lists the Windows host's certificate stores through powershell.exe
    // (WSL interop): roots (Root, AuthRoot) become a trust store, the CA store
    // (intermediates) completes chains. Takes about a second, hence on demand.
    private static final String WSL_PS_SCRIPT =
        "$ErrorActionPreference = 'SilentlyContinue'\n"
        + "foreach ($s in 'Root', 'AuthRoot', 'CA') {\n"
        + "  foreach ($l in 'LocalMachine', 'CurrentUser') {\n"
        + "    Get-ChildItem -Path ('Cert:\\' + $l + '\\' + $s) | ForEach-Object {\n"
        + "      $s + ' ' + [Convert]::ToBase64String($_.RawData) } } }\n";

    static void loadWslWindowsStores(List<Named> trust, List<X509Certificate> intermediates) {
        String ps = null;
        for (String dir : System.getenv().getOrDefault("PATH", "").split(":")) {
            if (!dir.isEmpty() && new File(dir, "powershell.exe").isFile()) {
                ps = new File(dir, "powershell.exe").getPath();
                break;
            }
        }
        if (ps == null) {
            String std = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe";
            if (new File(std).isFile()) ps = std;
        }
        if (ps == null) {
            debugLog("WSL: powershell.exe not found, Windows certificate stores not used");
            return;
        }
        File out = null;
        try {
            out = File.createTempFile("scm-tls", ".txt");
            // -EncodedCommand (UTF-16LE base64) avoids quoting through WSL interop.
            String enc = Base64.getEncoder().encodeToString(WSL_PS_SCRIPT.getBytes(StandardCharsets.UTF_16LE));
            ProcessBuilder pb = new ProcessBuilder(ps, "-NoProfile", "-NonInteractive", "-EncodedCommand", enc);
            pb.redirectInput(ProcessBuilder.Redirect.from(new File("/dev/null")));
            pb.redirectError(ProcessBuilder.Redirect.DISCARD);
            pb.redirectOutput(out);
            debugLog("WSL: reading Windows certificate stores via " + ps);
            Process p = pb.start();
            if (!p.waitFor(30, TimeUnit.SECONDS)) {
                p.destroyForcibly();
                debugLog("WSL: powershell.exe timed out");
                return;
            }
            List<X509Certificate> roots = new ArrayList<>();
            for (String line : Files.readAllLines(out.toPath(), StandardCharsets.ISO_8859_1)) {
                int sp = line.indexOf(' ');
                if (sp < 0) continue;
                X509Certificate c;
                try {
                    c = parseDer(Base64.getDecoder().decode(line.substring(sp + 1).trim()));
                } catch (IllegalArgumentException e) {
                    continue;
                }
                if (c == null) continue;
                if (line.startsWith("CA ")) intermediates.add(c);
                else roots.add(c);
            }
            debugLog("WSL: Windows stores: " + roots.size() + " root, "
                + intermediates.size() + " intermediate certificates");
            if (!roots.isEmpty()) addTrustManagers(trust, "windows-host (WSL)", keyStoreOf(roots));
        } catch (Exception e) {
            debugLog("WSL: cannot read Windows certificate stores: " + e);
        } finally {
            if (out != null) out.delete();
        }
    }

    static final class Named {
        final String name;
        final X509ExtendedTrustManager tm;
        Named(String name, X509ExtendedTrustManager tm) { this.name = name; this.tm = tm; }
    }

    // ks == null selects the JDK default trust store (cacerts or javax.net.ssl.trustStore).
    static void addTrustManagers(List<Named> out, String name, KeyStore ks) throws Exception {
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(ks);
        for (TrustManager tm : tmf.getTrustManagers()) {
            if (tm instanceof X509ExtendedTrustManager) {
                X509ExtendedTrustManager x = (X509ExtendedTrustManager) tm;
                out.add(new Named(name, x));
                debugLog("trust store " + name + ": " + x.getAcceptedIssuers().length + " certificates");
            }
        }
    }

    // Accepts a chain when any delegate accepts it. Delegates also perform the
    // host name check (endpoint identification), so that stays on. A server
    // chain rejected by all delegates is retried with the late stores (loaded
    // once, on the first rejection), then completed with intermediates from
    // the late stores' pool or downloaded via AIA and checked once more.
    static final class CompositeTrustManager extends X509ExtendedTrustManager {
        private static final int MAX_AIA_DOWNLOADS = 4;
        private final List<Named> delegates;
        private final LateStores lateStores;
        private volatile List<Named> lateTrust;
        private volatile List<X509Certificate> lateIntermediates = List.of();

        CompositeTrustManager(List<Named> delegates, LateStores lateStores) {
            this.delegates = delegates;
            this.lateStores = lateStores;
        }

        // True when the late stores were loaded just now (so are worth a retry).
        private boolean loadLate() {
            if (lateStores == null || lateTrust != null) return false;
            synchronized (this) {
                if (lateTrust != null) return false;
                List<Named> t = new ArrayList<>();
                List<X509Certificate> i = new ArrayList<>();
                lateStores.load(t, i);
                lateIntermediates = i;
                lateTrust = t;
                return true;
            }
        }

        private List<Named> all() {
            List<Named> late = lateTrust;
            if (late == null || late.isEmpty()) return delegates;
            List<Named> a = new ArrayList<>(delegates);
            a.addAll(late);
            return a;
        }

        private interface Check {
            void run(X509ExtendedTrustManager tm, X509Certificate[] chain) throws CertificateException;
        }

        private void anyServer(X509Certificate[] chain, Check check) throws CertificateException {
            List<String> reasons = new ArrayList<>();
            CertificateException first = tryAll(all(), chain, check, reasons);
            if (first == null) return;
            if (debug()) logChain("certificate chain sent by the server:", chain);
            if (loadLate() && !lateTrust.isEmpty()) {
                if (tryAll(lateTrust, chain, check, reasons) == null) return;
            }
            X509Certificate[] completed = completeChain(chain, lateIntermediates);
            if (completed.length > chain.length) {
                if (debug()) logChain("chain completed with issuer certificates:", completed);
                List<String> aiaReasons = new ArrayList<>();
                if (tryAll(all(), completed, check, aiaReasons) == null) return;
                for (String r : aiaReasons) reasons.add(r + " (after completing the chain)");
            }
            fail(first, reasons);
        }

        private void anyClient(X509Certificate[] chain, Check check) throws CertificateException {
            List<String> reasons = new ArrayList<>();
            CertificateException first = tryAll(delegates, chain, check, reasons);
            if (first != null) fail(first, reasons);
        }

        // Returns null when some delegate accepts the chain, else the first rejection.
        private static CertificateException tryAll(List<Named> ds, X509Certificate[] chain, Check check,
                                                   List<String> reasons) {
            CertificateException first = null;
            for (Named d : ds) {
                try {
                    check.run(d.tm, chain);
                    return null;
                } catch (CertificateException e) {
                    if (first == null) first = e;
                    reasons.add(d.name + ": " + e.getMessage());
                }
            }
            return first != null ? first : new CertificateException("no trust managers");
        }

        private static void fail(CertificateException first, List<String> reasons) throws CertificateException {
            for (String r : reasons) debugLog("rejected by " + r);
            if (reasons.size() <= 1) throw first;
            throw new CertificateException(String.join("; ", reasons), first);
        }

        public void checkServerTrusted(X509Certificate[] c, String a) throws CertificateException {
            anyServer(c, (tm, ch) -> tm.checkServerTrusted(ch, a));
        }
        public void checkServerTrusted(X509Certificate[] c, String a, Socket s) throws CertificateException {
            anyServer(c, (tm, ch) -> tm.checkServerTrusted(ch, a, s));
        }
        public void checkServerTrusted(X509Certificate[] c, String a, SSLEngine e) throws CertificateException {
            anyServer(c, (tm, ch) -> tm.checkServerTrusted(ch, a, e));
        }
        public void checkClientTrusted(X509Certificate[] c, String a) throws CertificateException {
            anyClient(c, (tm, ch) -> tm.checkClientTrusted(ch, a));
        }
        public void checkClientTrusted(X509Certificate[] c, String a, Socket s) throws CertificateException {
            anyClient(c, (tm, ch) -> tm.checkClientTrusted(ch, a, s));
        }
        public void checkClientTrusted(X509Certificate[] c, String a, SSLEngine e) throws CertificateException {
            anyClient(c, (tm, ch) -> tm.checkClientTrusted(ch, a, e));
        }
        public X509Certificate[] getAcceptedIssuers() {
            List<X509Certificate> all = new ArrayList<>();
            for (Named d : all()) {
                for (X509Certificate c : d.tm.getAcceptedIssuers()) all.add(c);
            }
            return all.toArray(new X509Certificate[0]);
        }
    }

    private static void logChain(String title, X509Certificate[] chain) {
        debugLog(title);
        for (int i = 0; i < chain.length; i++) {
            debugLog("  [" + i + "] subject: " + chain[i].getSubjectX500Principal());
            debugLog("      issuer:  " + chain[i].getIssuerX500Principal());
            debugLog("      valid:   " + chain[i].getNotBefore() + " .. " + chain[i].getNotAfter());
        }
    }

    // Appends issuer certificates of the chain's last certificate, from the
    // pool or else downloaded from its CA issuer URLs (AIA), until a
    // self-issued one is reached.
    static X509Certificate[] completeChain(X509Certificate[] chain, List<X509Certificate> pool) {
        List<X509Certificate> out = new ArrayList<>(Arrays.asList(chain));
        for (int n = 0; n < CompositeTrustManager.MAX_AIA_DOWNLOADS && !out.isEmpty(); n++) {
            X509Certificate last = out.get(out.size() - 1);
            if (last.getSubjectX500Principal().equals(last.getIssuerX500Principal())) break;
            X509Certificate issuer = fromPool(pool, last);
            if (issuer != null) debugLog("issuer from certificate store: " + issuer.getSubjectX500Principal());
            if (issuer == null) for (String url : caIssuerUrls(last)) {
                issuer = download(url, last);
                if (issuer != null) break;
            }
            if (issuer == null) break;
            out.add(issuer);
        }
        return out.toArray(new X509Certificate[0]);
    }

    private static X509Certificate fromPool(List<X509Certificate> pool, X509Certificate child) {
        for (X509Certificate c : pool) {
            if (!c.getSubjectX500Principal().equals(child.getIssuerX500Principal())) continue;
            try {
                child.verify(c.getPublicKey());
                return c;
            } catch (Exception e) {
                // same name, other key: keep looking
            }
        }
        return null;
    }

    private static X509Certificate download(String url, X509Certificate child) {
        if (!url.startsWith("http://") && !url.startsWith("https://")) return null;
        try {
            debugLog("downloading issuer certificate " + url);
            HttpURLConnection con = (HttpURLConnection) URI.create(url).toURL().openConnection();
            con.setConnectTimeout(5000);
            con.setReadTimeout(5000);
            try (InputStream in = con.getInputStream()) {
                // Handles DER, PEM and PKCS#7 (.p7c) responses.
                for (Certificate c : CertificateFactory.getInstance("X.509").generateCertificates(in)) {
                    if (c instanceof X509Certificate) {
                        X509Certificate x = (X509Certificate) c;
                        if (x.getSubjectX500Principal().equals(child.getIssuerX500Principal())) return x;
                    }
                }
            }
            debugLog("no matching issuer certificate at " + url);
        } catch (Exception e) {
            debugLog("download failed " + url + ": " + e);
        }
        return null;
    }

    // CA issuer URLs from the Authority Information Access extension
    // (1.3.6.1.5.5.7.1.1), parsed from DER without internal JDK classes.
    static List<String> caIssuerUrls(X509Certificate cert) {
        List<String> urls = new ArrayList<>();
        byte[] ext = cert.getExtensionValue("1.3.6.1.5.5.7.1.1");
        if (ext == null) return urls;
        try {
            Der octets = new Der(ext, 0);                     // OCTET STRING
            Der seq = new Der(ext, octets.start);             // SEQUENCE OF AccessDescription
            for (int p = seq.start; p < seq.end; ) {
                Der desc = new Der(ext, p);                   // AccessDescription SEQUENCE
                Der oid = new Der(ext, desc.start);           // accessMethod OID
                Der name = new Der(ext, oid.end);             // accessLocation GeneralName
                boolean caIssuers = Arrays.equals(Arrays.copyOfRange(ext, oid.start, oid.end), CA_ISSUERS_OID);
                if (caIssuers && name.tag == 0x86) {          // [6] uniformResourceIdentifier
                    urls.add(new String(ext, name.start, name.end - name.start, StandardCharsets.US_ASCII));
                }
                p = desc.end;
            }
        } catch (RuntimeException e) {
            debugLog("cannot parse AIA extension: " + e);
        }
        return urls;
    }

    // 1.3.6.1.5.5.7.48.2 (id-ad-caIssuers), DER-encoded OID body.
    private static final byte[] CA_ISSUERS_OID = { 0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x30, 0x02 };

    // One DER TLV: tag, and content bounds [start, end).
    static final class Der {
        final int tag, start, end;
        Der(byte[] b, int pos) {
            tag = b[pos] & 0xff;
            int len = b[pos + 1] & 0xff;
            int p = pos + 2;
            if (len > 0x7f) {
                int n = len & 0x7f;
                if (n > 4) throw new IllegalArgumentException("DER length too long");
                len = 0;
                for (int i = 0; i < n; i++) len = (len << 8) | (b[p++] & 0xff);
            }
            start = p;
            end = p + len;
            if (end > b.length) throw new IllegalArgumentException("truncated DER");
        }
    }

    // Must be an X509ExtendedTrustManager: a plain X509TrustManager gets wrapped
    // by JSSE, which then still enforces the host name check.
    static final class TrustAll extends X509ExtendedTrustManager {
        public void checkServerTrusted(X509Certificate[] c, String a) {}
        public void checkServerTrusted(X509Certificate[] c, String a, Socket s) {}
        public void checkServerTrusted(X509Certificate[] c, String a, SSLEngine e) {}
        public void checkClientTrusted(X509Certificate[] c, String a) {}
        public void checkClientTrusted(X509Certificate[] c, String a, Socket s) {}
        public void checkClientTrusted(X509Certificate[] c, String a, SSLEngine e) {}
        public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
    }
}
