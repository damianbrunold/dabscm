package scheme.json;

import java.io.IOException;
import java.io.PushbackReader;
import java.io.Reader;
import java.io.StringReader;
import java.util.ArrayList;
import java.util.List;

public class JsonLexer {

    private PushbackReader in;
    private List<String> tokens = new ArrayList<>();

    public JsonLexer(String data) {
        in = new PushbackReader(new StringReader(data), 1);
    }

    public JsonLexer(Reader reader) {
        in = new PushbackReader(reader, 1);
    }

    public void close() throws IOException {
        this.in.close();
    }

    public void putBackToken(String token) {
        tokens.add(token);
    }

    public String nextToken() throws IOException {
        if (!tokens.isEmpty()) {
            return tokens.remove(tokens.size() - 1);
        }
        StringBuilder result = new StringBuilder();
        int state = 0;
        int c = in.read();
        while (c != -1) {
            char ch = (char) c;
            switch (state) {
            case 0: // skip whitespace
                if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
                    break;
                } else if (ch == '"') {
                    state = 1;
                    result.append(ch);
                } else if (Character.isDigit(ch) || ch == '+' || ch == '-') {
                    state = 2;
                    result.append(ch);
                } else if (ch == ':' || ch == ',' || ch == '{'
                           || ch == '}' || ch == '[' || ch == ']') {
                    result.append(ch);
                    state = -1;
                } else {
                    state = 3;
                    result.append(ch);
                }
                break;

            case 1: // string
                if (ch == '\\') {
                    state = 4;
                } else if (ch == '"') {
                    result.append(ch);
                    state = -1;
                } else {
                    result.append(ch);
                }
                break;

            case 2: // integer
                if (Character.isDigit(ch)) {
                    result.append(ch);
                } else if (ch == '.') {
                    result.append(ch);
                    state = 21;
                } else {
                    in.unread(c);
                    state = -1;
                }
                break;

            case 21: // floating point
                if (Character.isDigit(ch)) {
                    result.append(ch);
                } else {
                    in.unread(c);
                    state = -1;
                }
                break;

            case 3: // keyword
                if ('a' <= ch && ch <= 'z') {
                    result.append(ch);
                } else {
                    in.unread(c);
                    state = -1;
                }
                break;

            case 4: // escape
                if (ch == '\\') {
                    result.append(ch);
                } else if (ch == '\"') {
                    result.append('\"');
                } else if (ch == 'b') {
                    result.append('\b');
                } else if (ch == 'f') {
                    result.append('\f');
                } else if (ch == 'n') {
                    result.append('\n');
                } else if (ch == 'r') {
                    result.append('\r');
                } else if (ch == 't') {
                    result.append('\t');
                } else if (ch == 'u') {
                    c = in.read();
                    if (c != -1) {
                        char ch1 = (char) c;
                        c = in.read();
                        if (c != -1) {
                            char ch2 = (char) c;
                            c = in.read();
                            if (c != -1) {
                                char ch3 = (char) c;
                                c = in.read();
                                if (c != -1) {
                                    char ch4 = (char) c;
                                    String s = "" + ch1 + ch2 + ch3 + ch4;
                                    char val = (char) Integer.parseInt(s, 16);
                                    result.append(Character.valueOf(val));
                                }
                            }
                        }
                    }
                } else {
                    result.append("\\").append(ch);
                }
                state = 1;
                break;
            }
            if (state == -1) break;
            c = in.read();
        }
        if (result.length() > 0) {
            return result.toString();
        } else {
            return null;
        }
    }

    public void matchToken(String token) throws IOException {
        String nexttoken = nextToken();
        if (!token.equals(nexttoken)) {
            String errmsg = "Expected " + token + " but got " + nexttoken;
            throw new RuntimeException(errmsg);
        }
    }
}
