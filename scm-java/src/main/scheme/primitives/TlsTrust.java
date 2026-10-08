package scheme.primitives;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.Socket;
import java.net.URI;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import javax.net.ssl.*;

// Shared TLS trust configuration for the HTTP client and verifying TLS sockets.
//
// The JDK only trusts its own cacerts file, while .NET (and browsers) on
// Windows use the Windows certificate store, which holds corporate root CAs
// deployed by group policy. To behave like the C# implementation, on Windows
// a certificate is accepted when either the JDK default trust store or one of
// the Windows root stores trusts it. Like Windows, intermediate certificates
// the server does not send are then downloaded from the CA issuer URL in the
// certificate's AIA extension. (The JDK's own AIA support is no use here:
// recent JDKs deny every URL not listed in com.sun.security.allowedAIALocations.)
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

    // The shared HttpClient used by http-get / http-post / http-send.
    public static HttpClient httpClient() throws Exception {
        HttpClient c = httpClient;
        if (c == null) {
            synchronized (TlsTrust.class) {
                c = httpClient;
                if (c == null) {
                    SSLContext ctx;
                    if (insecureRequested()) {
                        System.err.println("warning: SCM_TLS_INSECURE is set, "
                            + "HTTPS certificate verification is disabled");
                        ctx = insecureContext();
                    } else {
                        ctx = verifyingContext();
                    }
                    c = HttpClient.newBuilder().sslContext(ctx).build();
                    httpClient = c;
                }
            }
        }
        return c;
    }

    // SSLContext trusting the JDK default store plus, on Windows, the Windows root stores.
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
                    }
                    ctx = SSLContext.getInstance("TLS");
                    ctx.init(null, new TrustManager[]{ new CompositeTrustManager(tms, isWindows()) }, null);
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
    // host name check (endpoint identification), so that stays on. With
    // fetchAia, a server chain rejected by all delegates is completed with
    // intermediates downloaded via AIA and checked once more.
    static final class CompositeTrustManager extends X509ExtendedTrustManager {
        private static final int MAX_AIA_DOWNLOADS = 4;
        private final List<Named> delegates;
        private final boolean fetchAia;

        CompositeTrustManager(List<Named> delegates, boolean fetchAia) {
            this.delegates = delegates;
            this.fetchAia = fetchAia;
        }

        private interface Check {
            void run(X509ExtendedTrustManager tm, X509Certificate[] chain) throws CertificateException;
        }

        private void anyServer(X509Certificate[] chain, Check check) throws CertificateException {
            List<String> reasons = new ArrayList<>();
            CertificateException first = tryAll(chain, check, reasons);
            if (first == null) return;
            if (debug()) logChain("certificate chain sent by the server:", chain);
            if (fetchAia) {
                X509Certificate[] completed = completeChain(chain);
                if (completed.length > chain.length) {
                    if (debug()) logChain("chain completed via AIA:", completed);
                    List<String> aiaReasons = new ArrayList<>();
                    if (tryAll(completed, check, aiaReasons) == null) return;
                    for (String r : aiaReasons) reasons.add(r + " (after AIA download)");
                }
            }
            fail(first, reasons);
        }

        private void anyClient(X509Certificate[] chain, Check check) throws CertificateException {
            List<String> reasons = new ArrayList<>();
            CertificateException first = tryAll(chain, check, reasons);
            if (first != null) fail(first, reasons);
        }

        // Returns null when some delegate accepts the chain, else the first rejection.
        private CertificateException tryAll(X509Certificate[] chain, Check check, List<String> reasons) {
            CertificateException first = null;
            for (Named d : delegates) {
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
            for (Named d : delegates) {
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

    // Appends issuer certificates downloaded from the CA issuer URLs (AIA) of
    // the chain's last certificate, until a self-issued one is reached.
    static X509Certificate[] completeChain(X509Certificate[] chain) {
        List<X509Certificate> out = new ArrayList<>(Arrays.asList(chain));
        for (int n = 0; n < CompositeTrustManager.MAX_AIA_DOWNLOADS && !out.isEmpty(); n++) {
            X509Certificate last = out.get(out.size() - 1);
            if (last.getSubjectX500Principal().equals(last.getIssuerX500Principal())) break;
            X509Certificate issuer = null;
            for (String url : caIssuerUrls(last)) {
                issuer = download(url, last);
                if (issuer != null) break;
            }
            if (issuer == null) break;
            out.add(issuer);
        }
        return out.toArray(new X509Certificate[0]);
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
