package scheme.primitives;
import java.net.Socket;
import java.net.http.HttpClient;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;
import javax.net.ssl.*;

// Shared TLS trust configuration for the HTTP client and verifying TLS sockets.
//
// The JDK only trusts its own cacerts file, while .NET (and browsers) on
// Windows use the Windows certificate store, which holds corporate root CAs
// deployed by group policy. To behave like the C# implementation, on Windows
// a certificate is accepted when either the JDK default trust store or the
// Windows-ROOT store trusts it.
//
// SCM_TLS_INSECURE=1 (or true/yes) disables certificate and host name
// verification for the HTTP client (insecure; for broken intranet setups only).
public final class TlsTrust {
    private TlsTrust() {}

    private static volatile SSLContext verifyingContext;
    private static volatile HttpClient httpClient;

    public static boolean insecureRequested() {
        String v = System.getenv("SCM_TLS_INSECURE");
        if (v == null) return false;
        v = v.trim().toLowerCase();
        return v.equals("1") || v.equals("true") || v.equals("yes");
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

    // SSLContext trusting the JDK default store plus, on Windows, Windows-ROOT.
    public static SSLContext verifyingContext() throws Exception {
        SSLContext ctx = verifyingContext;
        if (ctx == null) {
            synchronized (TlsTrust.class) {
                ctx = verifyingContext;
                if (ctx == null) {
                    List<X509ExtendedTrustManager> tms = new ArrayList<>();
                    addTrustManagers(tms, null);
                    if (isWindows()) {
                        try {
                            KeyStore ks = KeyStore.getInstance("Windows-ROOT");
                            ks.load(null, null);
                            addTrustManagers(tms, ks);
                        } catch (Exception e) {
                            // Windows store unavailable: fall back to JDK defaults only.
                        }
                    }
                    ctx = SSLContext.getInstance("TLS");
                    TrustManager tm = tms.size() == 1 ? tms.get(0) : new CompositeTrustManager(tms);
                    ctx.init(null, new TrustManager[]{ tm }, null);
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

    // ks == null selects the JDK default trust store (cacerts or javax.net.ssl.trustStore).
    private static void addTrustManagers(List<X509ExtendedTrustManager> out, KeyStore ks) throws Exception {
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(ks);
        for (TrustManager tm : tmf.getTrustManagers()) {
            if (tm instanceof X509ExtendedTrustManager) out.add((X509ExtendedTrustManager) tm);
        }
    }

    // Accepts a server chain when any delegate accepts it. Delegates also
    // perform the host name check (endpoint identification), so that stays on.
    static final class CompositeTrustManager extends X509ExtendedTrustManager {
        private final List<X509ExtendedTrustManager> delegates;

        CompositeTrustManager(List<X509ExtendedTrustManager> delegates) {
            this.delegates = delegates;
        }

        private interface Check {
            void run(X509ExtendedTrustManager tm) throws CertificateException;
        }

        private void any(Check check) throws CertificateException {
            CertificateException first = null;
            for (X509ExtendedTrustManager tm : delegates) {
                try {
                    check.run(tm);
                    return;
                } catch (CertificateException e) {
                    if (first == null) first = e;
                }
            }
            throw first != null ? first : new CertificateException("no trust managers");
        }

        public void checkServerTrusted(X509Certificate[] c, String a) throws CertificateException {
            any(tm -> tm.checkServerTrusted(c, a));
        }
        public void checkServerTrusted(X509Certificate[] c, String a, Socket s) throws CertificateException {
            any(tm -> tm.checkServerTrusted(c, a, s));
        }
        public void checkServerTrusted(X509Certificate[] c, String a, SSLEngine e) throws CertificateException {
            any(tm -> tm.checkServerTrusted(c, a, e));
        }
        public void checkClientTrusted(X509Certificate[] c, String a) throws CertificateException {
            any(tm -> tm.checkClientTrusted(c, a));
        }
        public void checkClientTrusted(X509Certificate[] c, String a, Socket s) throws CertificateException {
            any(tm -> tm.checkClientTrusted(c, a, s));
        }
        public void checkClientTrusted(X509Certificate[] c, String a, SSLEngine e) throws CertificateException {
            any(tm -> tm.checkClientTrusted(c, a, e));
        }
        public X509Certificate[] getAcceptedIssuers() {
            List<X509Certificate> all = new ArrayList<>();
            for (X509ExtendedTrustManager tm : delegates) {
                for (X509Certificate c : tm.getAcceptedIssuers()) all.add(c);
            }
            return all.toArray(new X509Certificate[0]);
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
