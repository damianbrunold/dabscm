package scheme.primitives;

import scheme.*;
import java.security.cert.X509Certificate;
import javax.net.ssl.*;

public class PrimitiveTlsConnect extends Primitive {
    @Override
    public String name() { return "tls-connect"; }

    @Override
    public String info() {
        return "Syntax: (tls-connect host port)\n" +
               "Syntax: (tls-connect host port verify?)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Connects to a TCP server at host:port and immediately performs a TLS\n" +
               "  handshake (implicit TLS, as used by SMTPS on port 465 or HTTPS). Returns a socket\n" +
               "  whose ports read and write encrypted data transparently. When verify? is omitted or\n" +
               "  true, the server certificate chain and host name are validated; passing #f disables\n" +
               "  validation (insecure, for testing only).\n" +
               "Example:\n" +
               "  (define sock (tls-connect \"smtp.example.com\" 465))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        String host = new String(Value.asString(arguments[0]));
        int port = IntegerMath.toInt(arguments[1]);
        boolean verify = !(arguments.length > 2 && Boolean.FALSE.equals(arguments[2]));
        try {
            SSLSocketFactory factory = verify
                ? (SSLSocketFactory) SSLSocketFactory.getDefault()
                : insecureFactory();
            SSLSocket s = (SSLSocket) factory.createSocket(host, port);
            s.setTcpNoDelay(true);
            if (verify) {
                SSLParameters p = s.getSSLParameters();
                p.setEndpointIdentificationAlgorithm("HTTPS");
                s.setSSLParameters(p);
            }
            s.startHandshake();
            return new NativeValue(new SchemeSocket(s));
        } catch (Exception e) {
            throw new SchemeError(pos, "tls-connect: " + e.getMessage());
        }
    }

    // SSLSocketFactory that trusts all certificates (insecure; verify? = #f only).
    static SSLSocketFactory insecureFactory() throws Exception {
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, new TrustManager[]{ new TrustAllX509() }, null);
        return ctx.getSocketFactory();
    }

    static class TrustAllX509 implements X509TrustManager {
        public void checkClientTrusted(X509Certificate[] c, String a) {}
        public void checkServerTrusted(X509Certificate[] c, String a) {}
        public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
    }
}
