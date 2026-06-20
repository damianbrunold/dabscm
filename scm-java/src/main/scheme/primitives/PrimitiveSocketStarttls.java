package scheme.primitives;

import scheme.*;
import java.io.*;
import javax.net.ssl.*;

public class PrimitiveSocketStarttls extends Primitive {
    @Override
    public String name() { return "socket-starttls!"; }

    @Override
    public String info() {
        return "Syntax: (socket-starttls! socket host)\n" +
               "Syntax: (socket-starttls! socket host verify?)\n" +
               "Library: (scm net sockets)\n" +
               "Description: Upgrades an already-connected plaintext socket to TLS in place (the\n" +
               "  STARTTLS mechanism of SMTP/IMAP/etc.). Wraps the socket's raw underlying stream in\n" +
               "  a TLS stream and rebuilds the socket's input and output ports over it, so subsequent\n" +
               "  socket-input-port / socket-output-port use the encrypted channel. host is the server\n" +
               "  name used for certificate validation. When verify? is omitted or true, the server\n" +
               "  certificate chain and host name are validated; #f disables validation (insecure).\n" +
               "  The pre-upgrade dialogue must be read with socket-read-line so no plaintext past the\n" +
               "  upgrade boundary is buffered. Returns the socket.\n" +
               "Example:\n" +
               "  (socket-starttls! sock \"smtp.example.com\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        SchemeSocket ss = (SchemeSocket) Value.asNativeValue(arguments[0]).value;
        String host = new String(Value.asString(arguments[1]));
        boolean verify = !(arguments.length > 2 && Boolean.FALSE.equals(arguments[2]));
        try {
            SSLSocketFactory factory = verify
                ? (SSLSocketFactory) SSLSocketFactory.getDefault()
                : PrimitiveTlsConnect.insecureFactory();
            SSLSocket tls = (SSLSocket) factory.createSocket(
                ss.socket, host, ss.socket.getPort(), true);
            tls.setUseClientMode(true);
            if (verify) {
                SSLParameters p = tls.getSSLParameters();
                p.setEndpointIdentificationAlgorithm("HTTPS");
                tls.setSSLParameters(p);
            }
            tls.startHandshake();
            ss.socket = tls;
            ss.networkInputStream = tls.getInputStream();
            ss.networkOutputStream = tls.getOutputStream();
            ss.inputPort = new TextStream(
                new PushbackReader(new BufferedReader(
                    new InputStreamReader(ss.networkInputStream), 8192)),
                "{socket}");
            ss.outputPort = new TextOutputStream(
                new BufferedWriter(new OutputStreamWriter(ss.networkOutputStream), 8192));
            ss.binaryInputPort = null;
            ss.binaryOutputPort = null;
            return arguments[0];
        } catch (Exception e) {
            throw new SchemeError(pos, "socket-starttls!: " + e.getMessage());
        }
    }
}
