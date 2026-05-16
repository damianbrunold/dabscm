package scheme.json;

import java.io.IOException;
import java.io.Reader;

public class JsonParser {
    private JsonLexer lexer;
    private String listId = "data";
    private String status = "start";

    public JsonParser(String data) {
        lexer = new JsonLexer(data);
    }

    public JsonParser(Reader reader) {
        lexer = new JsonLexer(reader);
    }

    public JsonParser withListId(String listId) {
        this.listId = listId;
        return this;
    }

    public void close() throws IOException {
        this.lexer.close();
    }

    public JsonObject nextObject() throws IOException {
        if (status.equals("start")) {
            String token = lexer.nextToken();
            if (token != null && token.equals("{")) {
                token = lexer.nextToken();
                if (token != null && token.equals("\"" + listId + "\"")) {
                    lexer.matchToken(":");
                    lexer.matchToken("[");
                    status = "reading";
                    return parseObject();
                } else if (token != null) {
                    lexer.putBackToken(token);
                    lexer.putBackToken("{");
                    status = "reading";
                    return parseObject();
                }
            } else if (token != null && token.equals("[")) {
                status = "reading";
                return parseObject();
            }
            return null;
        } else if (status == "reading") {
            String token = lexer.nextToken();
            // optionally skip ,
            if (token != null && token.equals(",")) {
                token = lexer.nextToken();
            }
            // if ] found, we are at the end
            if (token == null ||token.equals("]")) {
                status = "end";
                return null;
            }
            lexer.putBackToken(token);
            return parseObject();
        } else {
            return null;
        }
    }

    public String nextToken() throws IOException {
        return lexer.nextToken();
    }

    public void matchToken(String token) throws IOException {
        lexer.matchToken(token);
    }

    public void putBackToken(String token) {
        lexer.putBackToken(token);
    }

    public JsonObject parseObject() throws IOException {
        JsonObject result = new JsonObject();
        lexer.matchToken("{");
        String token = lexer.nextToken();
        if (token == null) {
            throw new IllegalStateException("Unexpected end of tokens");
        }
        if (token.equals("}")) return result;
        while (true) {
            if (!token.startsWith("\"")) {
                String errmsg = "Expected string but got " + token;
                throw new IllegalStateException(errmsg);
            }
            String name = token.substring(1, token.length() - 1);
            lexer.matchToken(":");
            token = lexer.nextToken();
            if (token.equals("null")) {
                result.entries.put(name, new JsonNull());
            } else if (token.equals("true")) {
                result.entries.put(name, new JsonTrue());
            } else if (token.equals("false")) {
                result.entries.put(name, new JsonFalse());
            } else if (token.equals("{")) {
                lexer.putBackToken("{");
                result.entries.put(name, parseObject());
            } else if (token.equals("[")) {
                lexer.putBackToken("[");
                result.entries.put(name, parseList());
            } else if (token.startsWith("\"")) {
                String value = token.substring(1, token.length() - 1);
                result.entries.put(name, new JsonString(value));
            } else {
                double value = Double.parseDouble(token);
                result.entries.put(name, new JsonNumber(value));
            }
            token = lexer.nextToken();
            if (token == null) {
                throw new IllegalStateException("Unexpected end of tokens");
            }
            if (token.equals("}")) break;
            if (!token.equals(",")) {
                String errmsg = "Expected comma or end of object "
                    + "but got " + token;
                throw new IllegalStateException(errmsg);
            }
            token = lexer.nextToken();
            if (token == null) {
                throw new IllegalStateException("Unexpected end of tokens");
            }
        }
        return result;
    }

    public JsonList parseList() throws IOException {
        JsonList result = new JsonList();
        lexer.matchToken("[");
        String token = lexer.nextToken();
        if (token == null) {
            throw new IllegalStateException("Unexpected end of tokens");
        }
        if (token.equals("]")) return result;
        while (true) {
            if (token.equals("null")) {
                result.elements.add(new JsonNull());
            } else if (token.equals("true")) {
                result.elements.add(new JsonTrue());
            } else if (token.equals("false")) {
                result.elements.add(new JsonFalse());
            } else if (token.equals("{")) {
                lexer.putBackToken("{");
                result.elements.add(parseObject());
            } else if (token.equals("[")) {
                lexer.putBackToken("[");
                result.elements.add(parseList());
            } else if (token.startsWith("\"")) {
                String value = token.substring(1, token.length() - 1);
                result.elements.add(new JsonString(value));
            } else {
                double value = Double.parseDouble(token);
                result.elements.add(new JsonNumber(value));
            }
            token = lexer.nextToken();
            if (token == null) {
                throw new IllegalStateException("Unexpected end of tokens");
            }
            if (token.equals("]")) break;
            if (!token.equals(",")) {
                String errmsg = "Expected comma or end of list "
                    + "but got " + token;
                throw new IllegalStateException(errmsg);
            }
            token = lexer.nextToken();
            if (token == null) {
                throw new IllegalStateException("Unexpected end of tokens");
            }
        }
        return result;
    }
}
