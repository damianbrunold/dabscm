package scheme.primitives;

import scheme.*;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class PrimitiveRead extends Primitive {

    private Modules modules;

    public PrimitiveRead(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "read";
    }

    @Override
    public String info() {
        return "Syntax: (read)\n" +
               "Library: (scheme read)\n" +
               "Description: Reads an external representation of a Scheme object from the given port and returns the object. If no more objects are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
               "Example:\n" +
               "  (define p (open-input-string \"(a b c)\"))\n" +
               "  (read p) => (a b c)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        TextStream port;
        if (arguments.length == 0) {
            port = Value.asInputPort(modules.getModuleRequired(pos, "scm core").resolve(pos, "*input-port*"));
        } else {
            port = Value.asInputPort(arguments[0]);
        }
        try {
            return read(port);
        } catch (SchemeError e) {
            if (e.errorObject != null) throw e; // preserve ReadErrorObject/FileErrorObject
            throw new SchemeError(pos, new ReadErrorObject("read: " + e.getMessage(), new Object[0]));
        } catch (Exception e) {
            throw new SchemeError(pos, new ReadErrorObject("read: io failure: " + e.getMessage(), new Object[0]));
        }
    }

    public Object read(TextStream in) throws IOException {
        return readDatum(readToken(in), in, new HashMap<>());
    }

    public Object read(Token token, TextStream in) throws IOException {
        return readDatum(token, in, new HashMap<>());
    }

    private Object readDatum(Token token, TextStream in, Map<Integer, Object> labels) throws IOException {
        if (token == null) {
            return Value.EOF;
        }
        if (token.type == TokenType.DATUMCOMMENT) {
            readDatum(readToken(in), in, labels); // discard next datum
            return readDatum(readToken(in), in, labels);
        }
        if (token.type == TokenType.CLOSEPAR) {
            throw new SchemeError(token.pos, new ReadErrorObject("read: unexpected )", new Object[0]));
        }
        if (token.type == TokenType.INTEGER) {
            try { return Long.parseLong(token.value); }
            catch (NumberFormatException e) { return new java.math.BigInteger(token.value); }
        } else if (token.type == TokenType.RATIONAL) {
            int slash = token.value.indexOf('/');
            String ns = token.value.substring(0, slash), ds = token.value.substring(slash + 1);
            Object n, d;
            try { n = Long.parseLong(ns); } catch (NumberFormatException e) { n = new java.math.BigInteger(ns); }
            try { d = Long.parseLong(ds); } catch (NumberFormatException e) { d = new java.math.BigInteger(ds); }
            return Rational.create(n, d);
        } else if (token.type == TokenType.REAL) {
            if (token.value.equals("+inf.0")) return Double.POSITIVE_INFINITY;
            if (token.value.equals("-inf.0")) return Double.NEGATIVE_INFINITY;
            if (token.value.equals("+nan.0")) return Double.NaN;
            // Normalize R7RS exponent markers (s, f, d, l) to 'e'
            return Double.parseDouble(token.value.replaceAll("[sfdlSFDL]", "e"));
        } else if (token.type == TokenType.COMPLEX) {
            return parseComplexToken(token.value, token.pos);
        } else if (token.type == TokenType.STRING) {
            return token.value.toCharArray();
        } else if (token.type == TokenType.CHARACTER) {
            return token.value.charAt(0);
        } else if (token.type == TokenType.TRUE) {
            return Value.T;
        } else if (token.type == TokenType.FALSE) {
            return Value.F;
        } else if (token.type == TokenType.SYMBOL) {
            return Value.intern(token.value);
        } else if (token.type == TokenType.QUOTE) {
            return Pair.list(Value.intern("quote"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.BACKQUOTE) {
            return Pair.list(Value.intern("quasiquote"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.COMMA) {
            return Pair.list(Value.intern("unquote"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.COMMAAT) {
            return Pair.list(Value.intern("unquote-splicing"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.SYNTAX) {
            return Pair.list(Value.intern("syntax"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.QUASISYNTAX) {
            return Pair.list(Value.intern("quasisyntax"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.UNSYNTAX) {
            return Pair.list(Value.intern("unsyntax"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.UNSYNTAXSPLICING) {
            return Pair.list(Value.intern("unsyntax-splicing"), readDatum(readToken(in), in, labels));
        } else if (token.type == TokenType.OPENPAR) {
            token = readToken(in);
            if (token == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
            if (token.type == TokenType.CLOSEPAR) {
                return Value.NIL;
            } else {
                Pair result = new Pair(readDatum(token, in, labels), Value.NIL, token.pos);
                Pair current = result;
                token = readToken(in);
                while (token != null && token.type != TokenType.CLOSEPAR && token.type != TokenType.DOT) {
                    Object value = readDatum(token, in, labels);
                    Pair next = new Pair(value, Value.NIL);
                    current.cdr = next;
                    current = next;
                    token = readToken(in);
                }
                if (token == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
                if (token.type == TokenType.DOT) {
                    current.cdr = readDatum(readToken(in), in, labels);
                    token = readToken(in);
                    while (token != null && token.type == TokenType.DATUMCOMMENT) {
                        readDatum(readToken(in), in, labels); // discard commented datum
                        token = readToken(in);
                    }
                }
                if (token == null || token.type != TokenType.CLOSEPAR) {
                    throw new SchemeError(in.pos(), new ReadErrorObject("read: expected )", new Object[0]));
                }
                return result;
            }
        } else if (token.type == TokenType.SHARPOPENPAR) {
            List<Object> elements = new ArrayList<>();
            token = readToken(in);
            while (token != null && token.type != TokenType.CLOSEPAR) {
                elements.add(readDatum(token, in, labels));
                token = readToken(in);
            }
            if (token == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
            return elements.toArray();
        } else if (token.type == TokenType.BYTEVECTOROPENPAR) {
            java.io.ByteArrayOutputStream bv = new java.io.ByteArrayOutputStream();
            token = readToken(in);
            while (token != null && token.type != TokenType.CLOSEPAR) {
                Object elem = readDatum(token, in, labels);
                if (!Value.isInteger(elem))
                    throw new SchemeError(token.pos, new ReadErrorObject("read: bytevector elements must be exact integers", new Object[] { elem }));
                long val = IntegerMath.toLong(elem);
                if (val < 0 || val > 255)
                    throw new SchemeError(token.pos, new ReadErrorObject("read: bytevector element out of range", new Object[] { val }));
                bv.write((int) val);
                token = readToken(in);
            }
            if (token == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
            return bv.toByteArray();
        } else if (token.type == TokenType.LABELDEFINITION) {
            int labelN = Integer.parseInt(token.value);
            Token next = readToken(in);
            if (next.type == TokenType.OPENPAR) {
                Token firstTok = readToken(in);
                if (firstTok.type == TokenType.CLOSEPAR) {
                    labels.put(labelN, Value.NIL);
                    return Value.NIL;
                }
                Pair result = new Pair(null, Value.NIL, next.pos);
                labels.put(labelN, result);
                result.car = readDatum(firstTok, in, labels);
                Pair current = result;
                Token t = readToken(in);
                while (t != null && t.type != TokenType.CLOSEPAR && t.type != TokenType.DOT) {
                    Pair nxt = new Pair(readDatum(t, in, labels), Value.NIL);
                    current.cdr = nxt;
                    current = nxt;
                    t = readToken(in);
                }
                if (t == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
                if (t.type == TokenType.DOT) {
                    current.cdr = readDatum(readToken(in), in, labels);
                    readToken(in); // consume closing )
                }
                return result;
            } else if (next.type == TokenType.SHARPOPENPAR) {
                List<Object> elements = new ArrayList<>();
                Token t = readToken(in);
                while (t != null && t.type != TokenType.CLOSEPAR) {
                    elements.add(readDatum(t, in, labels));
                    t = readToken(in);
                }
                if (t == null) throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected end of file", new Object[0]));
                Object[] vec = elements.toArray();
                labels.put(labelN, vec);
                return vec;
            } else {
                Object val = readDatum(next, in, labels);
                labels.put(labelN, val);
                return val;
            }
        } else if (token.type == TokenType.LABELREFERENCE) {
            int labelN = Integer.parseInt(token.value);
            if (!labels.containsKey(labelN))
                throw new SchemeError(token.pos, new ReadErrorObject("read: undefined datum label", new Object[] { (long) labelN }));
            return labels.get(labelN);
        } else {
            throw new SchemeError(in.pos(), new ReadErrorObject("read: unexpected token", new Object[] { token.toString().toCharArray() }));
        }
    }

    public static Token readToken(TextStream reader) throws IOException {
        return Tokenizer.readToken(reader);
    }

    private static Object parseComplexToken(String value, SourcePos pos) {
        // Polar form: "magnitude@angle"
        int atIdx = value.indexOf('@');
        if (atIdx >= 0) {
            String magStr = value.substring(0, atIdx);
            String angStr = value.substring(atIdx + 1);
            double mag = parseRealStr(magStr);
            double ang = parseRealStr(angStr);
            return Complex.create(mag * Math.cos(ang), mag * Math.sin(ang));
        }

        // Rectangular form: "realPart|imagPart"
        int pipe = value.indexOf('|');
        if (pipe < 0)
            throw new SchemeError(pos, "read: invalid complex token: ~s", value);
        String realStr = value.substring(0, pipe);
        String imagStr = value.substring(pipe + 1);
        Object realPart = parseNumberStr(realStr);
        Object imagPart = parseNumberStr(imagStr);
        return Complex.create(realPart, imagPart);
    }

    private static Object parseNumberStr(String s) {
        if (s.equals("+inf.0")) return Double.POSITIVE_INFINITY;
        if (s.equals("-inf.0")) return Double.NEGATIVE_INFINITY;
        if (s.equals("+nan.0") || s.equals("-nan.0")) return Double.NaN;
        if (s.contains("/")) {
            int slash = s.indexOf('/');
            String ns = s.substring(0, slash), ds = s.substring(slash + 1);
            Object n, d;
            try { n = Long.parseLong(ns); } catch (NumberFormatException e) { n = new java.math.BigInteger(ns); }
            try { d = Long.parseLong(ds); } catch (NumberFormatException e) { d = new java.math.BigInteger(ds); }
            return Rational.create(n, d);
        }
        if (s.contains(".") || s.matches(".*[eEsSfFdDlL].*")) {
            return Double.parseDouble(s.replaceAll("[sfdlSFDL]", "e"));
        }
        try { return Long.parseLong(s); }
        catch (NumberFormatException e) { return new java.math.BigInteger(s); }
    }

    private static double parseRealStr(String s) {
        if (s.equals("+inf.0")) return Double.POSITIVE_INFINITY;
        if (s.equals("-inf.0")) return Double.NEGATIVE_INFINITY;
        if (s.equals("+nan.0") || s.equals("-nan.0")) return Double.NaN;
        return Double.parseDouble(s.replaceAll("[sfdlSFDL]", "e"));
    }
}
