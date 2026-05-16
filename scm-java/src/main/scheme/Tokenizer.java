package scheme;

import java.io.IOException;

public class Tokenizer {

    private static String maybeFold(TextStream in, String s) {
        return in.foldCase ? s.toLowerCase() : s;
    }

    // R7RS exponent markers: e (default), s (short), f (single), d (double), l (long)
    private static boolean isExponentMarker(int ch) {
        return ch == 'e' || ch == 'E' || ch == 's' || ch == 'S' ||
               ch == 'f' || ch == 'F' || ch == 'd' || ch == 'D' ||
               ch == 'l' || ch == 'L';
    }

    public static Token readToken(TextStream in) throws IOException {
        String whitespace = " \r\n\t";
        String delim = "()[]\"" + whitespace;
        int c = in.peek();
        int state = 0;
        int nestDepth = 0;
        StringBuilder token = new StringBuilder();
        StringBuilder hexBuf = null;
        StringBuilder heredocMarker = null;
        StringBuilder lineBuffer = null;
        boolean putback = false;
        SourcePos pos = in.pos();
        while (c != -1) {
            char ch = (char) c;
            switch (state) {
                case 0: // whitespace or single char token
                    if (ch == '(' || ch == '[') {
                        in.read();
                        return new Token("(", TokenType.OPENPAR, pos);
                    } else if (ch == ')' || ch == ']') {
                        in.read();
                        return new Token(")", TokenType.CLOSEPAR, pos);
                    } else if (ch == '\'') {
                        in.read();
                        return new Token("'", TokenType.QUOTE, pos);
                    } else if (ch == '`') {
                        in.read();
                        return new Token("`", TokenType.BACKQUOTE, pos);
                    } else if (ch == ',') {
                        state = 4; // unquote, unquote-splicing
                        pos = in.pos();
                    } else if (ch == '.') {
                        state = 12; // either dot or real
                        token.append(ch);
                    } else if (ch == ';') {
                        state = 7; // comment
                    } else if (whitespace.indexOf(ch) != -1) {
                        break;
                    } else if (('0' <= ch && ch <= '9') || ch == '+' || ch == '-') {
                        state = 1; // number, +, -
                        token.append(ch);
                    } else if (ch == '\"') {
                        state = 2; // string
                    } else if (ch == '#') {
                        state = 5; // sharp stuff
                    } else if (ch == '|') {
                        state = 30; // delimited identifier |...|
                    } else {
                        state = 3; // symbol
                        token.append(ch);
                    }
                    break;

                case 1: // number, +,  -
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                    } else if (ch == '.') {
                        token.append(ch);
                        state = 11; // real
                    } else if (ch == '/') {
                        token.append(ch);
                        state = 13; // rational denominator
                    } else if (isExponentMarker(ch)) {
                        token.append(ch);
                        state = 14; // exponent
                    } else if (delim.indexOf(ch) != -1) {
                        putback = true;
                        if (token.toString().equals("+")) {
                            return new Token(maybeFold(in, "+"), TokenType.SYMBOL, pos);
                        } else if (token.toString().equals("-")) {
                            return new Token(maybeFold(in, "-"), TokenType.SYMBOL, pos);
                        } else {
                            return new Token(token.toString(), TokenType.INTEGER, pos);
                        }
                    } else if ((ch == '+' || ch == '-') && token.length() > 0 &&
                               !(token.length() == 1 && (token.charAt(0) == '+' || token.charAt(0) == '-'))) {
                        // Complex number: real part is integer, imaginary follows
                        return readComplexImaginary(in, token.toString(), pos);
                    } else if ((ch == 'i' || ch == 'I') && token.length() > 0 &&
                               (token.charAt(0) == '+' || token.charAt(0) == '-')) {
                        // Pure imaginary: +Ni, -Ni, +i, -i
                        in.read();
                        int next = in.peek();
                        if (isDelimiterOrEnd(next, delim)) {
                            String imagStr = token.toString();
                            if (imagStr.equals("+") || imagStr.equals("-"))
                                imagStr += "1";
                            return new Token("0|" + imagStr, TokenType.COMPLEX, pos);
                        }
                        // Not pure imaginary — continue as symbol
                        token.append('i');
                        state = 3;
                        c = in.peek();
                        putback = true;
                        break;
                    } else if (ch == '@' && token.length() > 0 &&
                               !(token.length() == 1 && (token.charAt(0) == '+' || token.charAt(0) == '-'))) {
                        return readPolarForm(in, token.toString(), pos);
                    } else {
                        token.append(ch);
                        state = 3; // symbol
                    }
                    break;

                case 13: // rational denominator (e.g. "1/3")
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                    } else if (ch == '+' || ch == '-') {
                        return readComplexImaginary(in, token.toString(), pos);
                    } else if ((ch == 'i' || ch == 'I') && (token.charAt(0) == '+' || token.charAt(0) == '-')) {
                        // Pure imaginary rational: +3/4i
                        in.read();
                        int next = in.peek();
                        if (isDelimiterOrEnd(next, delim)) {
                            return new Token("0|" + token.toString(), TokenType.COMPLEX, pos);
                        }
                        token.append('i');
                        state = 3;
                        c = in.peek();
                        putback = true;
                        break;
                    } else if (ch == '@') {
                        return readPolarForm(in, token.toString(), pos);
                    } else {
                        putback = true;
                        return new Token(token.toString(), TokenType.RATIONAL, pos);
                    }
                    break;

                case 11: // real
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                    } else if (isExponentMarker(ch)) {
                        token.append(ch);
                        state = 14; // exponent
                    } else {
                        String rtok = token.toString();
                        if (rtok.equals("+.")) {
                            putback = true;
                            return new Token(maybeFold(in, "+"), TokenType.SYMBOL, pos);
                        } else if (rtok.equals("-.")) {
                            putback = true;
                            return new Token(maybeFold(in, "-"), TokenType.SYMBOL, pos);
                        } else if (ch == '+' || ch == '-') {
                            return readComplexImaginary(in, rtok, pos);
                        } else if ((ch == 'i' || ch == 'I') && (rtok.charAt(0) == '+' || rtok.charAt(0) == '-')) {
                            in.read();
                            int next = in.peek();
                            if (isDelimiterOrEnd(next, delim))
                                return new Token("0|" + rtok, TokenType.COMPLEX, pos);
                            token.append('i');
                            state = 3;
                            c = in.peek();
                            putback = true;
                            break;
                        } else if (ch == '@') {
                            return readPolarForm(in, rtok, pos);
                        } else {
                            putback = true;
                            return new Token(rtok, TokenType.REAL, pos);
                        }
                    }
                    break;

                case 14: // seen e/E, awaiting optional sign or first exponent digit
                    if (ch == '+' || ch == '-' || ('0' <= ch && ch <= '9')) {
                        token.append(ch);
                        state = 15;
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed exponent", new Object[0]));
                    }
                    break;

                case 15: // accumulating exponent digits
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                    } else if (ch == '+' || ch == '-') {
                        return readComplexImaginary(in, token.toString(), pos);
                    } else if (ch == '@') {
                        return readPolarForm(in, token.toString(), pos);
                    } else {
                        putback = true;
                        return new Token(token.toString(), TokenType.REAL, pos);
                    }
                    break;

                case 12: // dot or real
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                        state = 11;
                    } else if (ch == '.') {
                        // ".." or "..." — treat as symbol (R7RS identifiers)
                        token.append(ch);
                        state = 3;
                    } else {
                        putback = true;
                        return new Token(".", TokenType.DOT, pos);
                    }
                    break;

                case 2: // string
                    if (ch == '\\') {
                        state = 21; // string escape
                    } else if (ch == '\"') {
                        in.read();
                        return new Token(token.toString(), TokenType.STRING, pos);
                    } else if (ch != '\r') {
                        token.append(ch);
                    }
                    break;

                case 21: // string escape
                    if (ch == '"' || ch == '\\') {
                        token.append(ch);
                        state = 2;
                    } else if (ch == 'n') {
                        token.append('\n');
                        state = 2;
                    } else if (ch == 'r') {
                        token.append('\r');
                        state = 2;
                    } else if (ch == 't') {
                        token.append('\t');
                        state = 2;
                    } else if (ch == 'a') {
                        token.append('\u0007');
                        state = 2;
                    } else if (ch == 'b') {
                        token.append('\b');
                        state = 2;
                    } else if (ch == '|') {
                        token.append('|');
                        state = 2;
                    } else if (ch == '0') {
                        token.append('\0');
                        state = 2;
                    } else if (ch == 'x') {
                        if (hexBuf == null) hexBuf = new StringBuilder();
                        hexBuf.setLength(0);
                        state = 22;
                    } else if (ch == ' ' || ch == '\t') {
                        state = 23; // skip intraline whitespace before line ending
                    } else if (ch == '\n') {
                        state = 25; // saw \n, skip trailing intraline whitespace only
                    } else if (ch == '\r') {
                        state = 24; // saw \r, may need to consume \n of \r\n
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid string escape: \\" + ch, new Object[0]));
                    }
                    break;

                case 22: // hex string escape \xNNN;
                    if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')) {
                        hexBuf.append(ch);
                    } else if (ch == ';') {
                        if (hexBuf.length() == 0)
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: empty hex escape \\x;", new Object[0]));
                        int codepoint = Integer.parseInt(hexBuf.toString(), 16);
                        token.append(new String(Character.toChars(codepoint)));
                        state = 2;
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed hex escape", new Object[0]));
                    }
                    break;

                case 23: // line continuation — skip intraline whitespace before line ending
                    if (ch == ' ' || ch == '\t') {
                        // skip, stay in 23
                    } else if (ch == '\n') {
                        state = 25; // saw \n, skip trailing intraline whitespace only
                    } else if (ch == '\r') {
                        state = 24; // saw \r, may need to consume \n of \r\n
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid string escape: expected newline in line continuation", new Object[0]));
                    }
                    break;

                case 24: // line continuation — saw \r, may need to consume \n of \r\n
                    if (ch == '\n') {
                        // consume the \n of \r\n, then skip trailing intraline whitespace
                        state = 25;
                    } else if (ch == ' ' || ch == '\t') {
                        // no \n after \r; skip trailing intraline whitespace
                        state = 25;
                    } else {
                        putback = true;
                        state = 2;
                    }
                    break;

                case 25: // line continuation — skip trailing intraline whitespace only
                    if (ch == ' ' || ch == '\t') {
                        // skip intraline whitespace, stay in 25
                    } else {
                        putback = true;
                        state = 2;
                    }
                    break;

                case 3: // symbol
                    if (delim.indexOf(ch) != -1) {
                        putback = true;
                        String sym = maybeFold(in, token.toString());
                        String symLower = sym.toLowerCase();
                        if (symLower.equals("+inf.0") || symLower.equals("-inf.0") || symLower.equals("+nan.0"))
                            return new Token(symLower, TokenType.REAL, pos);
                        return new Token(sym, TokenType.SYMBOL, pos);
                    } else if ((ch == '+' || ch == '-') && token.length() >= 5) {
                        String symLower = token.toString().toLowerCase();
                        if (symLower.equals("+inf.0") || symLower.equals("-inf.0") || symLower.equals("+nan.0"))
                            return readComplexImaginary(in, symLower, pos);
                        token.append(ch);
                    } else {
                        token.append(ch);
                    }
                    break;

                case 4: // unquote, unquote-splicing
                    if (ch == '@') {
                        in.read();
                        return new Token(",@", TokenType.COMMAAT, pos);
                    } else {
                        putback = true;
                        return new Token(",", TokenType.COMMA, pos);
                    }

                case 5: // sharp stuff
                    if (ch == 't') {
                        token.append(ch);
                        state = 56; // reading #t or #true
                    } else if (ch == 'f') {
                        token.append(ch);
                        state = 57; // reading #f or #false
                    } else if (ch == '(') {
                        in.read();
                        return new Token("#(", TokenType.SHARPOPENPAR, pos);
                    } else if (ch == ';') {
                        in.read();
                        return new Token("#;", TokenType.DATUMCOMMENT, pos);
                    } else if (ch == '|') {
                        nestDepth = 1;
                        state = 58; // block comment
                    } else if (ch == 'u') {
                        state = 50; // #u...
                    } else if (ch == '\\') {
                        state = 6; // character
                    } else if ('0' <= ch && ch <= '9') {
                        state = 52; // datum label #N= or #N#
                        token.append(ch);
                    } else if (ch == '<') {
                        state = 53; // heredoc: expect second <
                    } else if (ch == 'b' || ch == 'B') {
                        in.read();
                        boolean[] ei2 = new boolean[]{false, false};
                        if (in.peek() == '#') { in.read(); readExactnessPrefix(in, pos, ei2); }
                        return readPrefixedNumberOrComplex(in, 2, ei2[0], ei2[1], pos);
                    } else if (ch == 'o' || ch == 'O') {
                        in.read();
                        boolean[] ei2 = new boolean[]{false, false};
                        if (in.peek() == '#') { in.read(); readExactnessPrefix(in, pos, ei2); }
                        return readPrefixedNumberOrComplex(in, 8, ei2[0], ei2[1], pos);
                    } else if (ch == 'x' || ch == 'X') {
                        in.read();
                        boolean[] ei2 = new boolean[]{false, false};
                        if (in.peek() == '#') { in.read(); readExactnessPrefix(in, pos, ei2); }
                        return readPrefixedNumberOrComplex(in, 16, ei2[0], ei2[1], pos);
                    } else if (ch == 'd' || ch == 'D') {
                        in.read();
                        boolean[] ei2 = new boolean[]{false, false};
                        if (in.peek() == '#') { in.read(); readExactnessPrefix(in, pos, ei2); }
                        return readPrefixedNumberOrComplex(in, 10, ei2[0], ei2[1], pos);
                    } else if (ch == 'e' || ch == 'E') {
                        in.read();
                        int peeked = in.peek();
                        if (peeked == '#') {
                            in.read(); // consume second '#'
                            int radixCh = in.peek();
                            in.read(); // consume radix char
                            int r2 = prefixToRadix((char) radixCh, pos);
                            return readPrefixedNumberOrComplex(in, r2, true, false, pos);
                        }
                        return readPrefixedNumberOrComplex(in, 10, true, false, pos);
                    } else if (ch == 'i' || ch == 'I') {
                        in.read();
                        int peeked = in.peek();
                        if (peeked == '#') {
                            in.read(); // consume second '#'
                            int radixCh = in.peek();
                            in.read(); // consume radix char
                            int r2 = prefixToRadix((char) radixCh, pos);
                            return readPrefixedNumberOrComplex(in, r2, false, true, pos);
                        }
                        return readPrefixedNumberOrComplex(in, 10, false, true, pos);
                    } else if (ch == '\'') {
                        in.read();
                        return new Token("#'", TokenType.SYNTAX, pos);
                    } else if (ch == '`') {
                        in.read();
                        return new Token("#`", TokenType.QUASISYNTAX, pos);
                    } else if (ch == ',') {
                        in.read(); // consume ','
                        int next = in.peek();
                        if (next == '@') {
                            in.read(); // consume '@'
                            return new Token("#,@", TokenType.UNSYNTAXSPLICING, pos);
                        }
                        return new Token("#,", TokenType.UNSYNTAX, pos);
                    } else if (ch == '!') {
                        in.read(); // consume '!'
                        // Shebang line: #!/ treated as line comment (R6RS §4.2.1)
                        if (in.peek() == '/') {
                            int sc = in.peek();
                            while (sc != -1 && sc != '\n') {
                                in.read();
                                sc = in.peek();
                            }
                            token.setLength(0);
                            state = 0;
                            c = in.peek();
                            continue;
                        }
                        StringBuilder directive = new StringBuilder();
                        int dc = in.peek();
                        while (dc != -1 && "()[]\" \r\n\t".indexOf((char) dc) == -1) {
                            directive.append((char) dc);
                            in.read();
                            dc = in.peek();
                        }
                        String dir = directive.toString().toLowerCase();
                        if (dir.equals("fold-case")) {
                            in.foldCase = true;
                        } else if (dir.equals("no-fold-case")) {
                            in.foldCase = false;
                        } else {
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown directive: #!" + directive, new Object[0]));
                        }
                        token.setLength(0);
                        state = 0;
                        c = in.peek();
                        continue;
                    } else {
                        in.read();
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence: #" + ch, new Object[0]));
                    }
                    break;

                case 56: // reading #t or #true
                    if (delim.indexOf(ch) != -1) {
                        putback = true;
                        String tv = token.toString();
                        if (tv.equals("t") || tv.equals("true"))
                            return new Token("#t", TokenType.TRUE, pos);
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid boolean literal: #" + tv, new Object[0]));
                    } else {
                        token.append(ch);
                    }
                    break;

                case 57: // reading #f or #false
                    if (delim.indexOf(ch) != -1) {
                        putback = true;
                        String fv = token.toString();
                        if (fv.equals("f") || fv.equals("false"))
                            return new Token("#f", TokenType.FALSE, pos);
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid boolean literal: #" + fv, new Object[0]));
                    } else {
                        token.append(ch);
                    }
                    break;

                case 58: // block comment body
                    if (ch == '|') state = 59;
                    else if (ch == '#') state = 60;
                    // else stay in 58
                    break;

                case 59: // block comment: previous char was '|'
                    if (ch == '#') {
                        nestDepth--;
                        if (nestDepth == 0) {
                            token.setLength(0);
                            state = 0;
                        } else {
                            state = 58;
                        }
                    } else if (ch == '|') { /* stay in 59 */ }
                    else state = 58;
                    break;

                case 60: // block comment: previous char was '#'
                    if (ch == '|') { nestDepth++; state = 58; }
                    else if (ch == '#') { /* stay in 60 */ }
                    else state = 58;
                    break;

                case 52: // accumulating label number after #
                    if ('0' <= ch && ch <= '9') {
                        token.append(ch);
                        break;
                    }
                    if (ch == '=') {
                        in.read();
                        return new Token(token.toString(), TokenType.LABELDEFINITION, pos);
                    }
                    if (ch == '#') {
                        in.read();
                        return new Token(token.toString(), TokenType.LABELREFERENCE, pos);
                    }
                    throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed datum label", new Object[0]));

                case 50: // #u...
                    if (ch == '8') {
                        state = 51; // #u8...
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence", new Object[0]));
                    }
                    break;

                case 51: // #u8...
                    if (ch == '(') {
                        in.read();
                        return new Token("#u8(", TokenType.BYTEVECTOROPENPAR, pos);
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence", new Object[0]));
                    }

                case 6: // character
                    token.append(ch);
                    state = 61;
                    break;

                case 61: // character
                    if (delim.indexOf(ch) != -1) {
                        putback = true;
                        return asCharacterToken(token.toString(), pos);
                    } else {
                        token.append(ch);
                    }
                    break;

                case 53: // heredoc: second <
                    if (ch == '<') {
                        state = 54; // now read marker name
                        if (heredocMarker == null) heredocMarker = new StringBuilder();
                        heredocMarker.setLength(0);
                    } else {
                        in.read();
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected #<< for heredoc", new Object[0]));
                    }
                    break;

                case 54: // reading heredoc marker name
                    if (ch == '\r') break; // skip CR
                    if (ch == '\n') {
                        state = 55; // start reading body
                        if (lineBuffer == null) lineBuffer = new StringBuilder();
                        lineBuffer.setLength(0);
                    } else {
                        heredocMarker.append(ch);
                    }
                    break;

                case 55: // reading heredoc body
                    if (ch == '\r') break; // skip CR
                    if (ch == '\n') {
                        if (lineBuffer.toString().equals(heredocMarker.toString())) {
                            in.read();
                            return new Token(token.toString(), TokenType.STRING, pos);
                        }
                        token.append(lineBuffer);
                        token.append('\n');
                        lineBuffer.setLength(0);
                    } else {
                        lineBuffer.append(ch);
                    }
                    break;

                case 30: // delimited identifier |...|
                    if (ch == '|') {
                        in.read();
                        return new Token(token.toString(), TokenType.SYMBOL, pos);
                    } else if (ch == '\\') {
                        state = 31; // escape inside delimited identifier
                    } else {
                        token.append(ch);
                    }
                    break;

                case 31: // escape inside delimited identifier
                    if (ch == 'x') {
                        if (hexBuf == null) hexBuf = new StringBuilder();
                        hexBuf.setLength(0);
                        state = 32;
                    } else if (ch == '\\' || ch == '|') {
                        token.append(ch);
                        state = 30;
                    } else if (ch == 'a') {
                        token.append('\u0007');
                        state = 30;
                    } else if (ch == 'b') {
                        token.append('\b');
                        state = 30;
                    } else if (ch == 'n') {
                        token.append('\n');
                        state = 30;
                    } else if (ch == 'r') {
                        token.append('\r');
                        state = 30;
                    } else if (ch == 't') {
                        token.append('\t');
                        state = 30;
                    } else if (ch == '"') {
                        token.append('"');
                        state = 30;
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid escape in delimited identifier: \\" + ch, new Object[0]));
                    }
                    break;

                case 32: // hex escape inside delimited identifier \xNNN;
                    if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')) {
                        hexBuf.append(ch);
                    } else if (ch == ';') {
                        if (hexBuf.length() == 0)
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: empty hex escape \\x;", new Object[0]));
                        int codepoint = Integer.parseInt(hexBuf.toString(), 16);
                        token.append(new String(Character.toChars(codepoint)));
                        state = 30;
                    } else {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed hex escape in delimited identifier", new Object[0]));
                    }
                    break;

                case 7: // comment
                    if (ch == '\n') state = 0;
                    pos = in.pos();
                    break;
            }
            if (!putback) {
                in.read();
                c = in.peek();
            } else {
                putback = false;
            }
        }
        if (state == 0 && (token == null || token.length() == 0)) return null;
        if (state == 1) {
            if (token.toString().equals("+") || token.toString().equals("-")) {
                return new Token(maybeFold(in, token.toString()), TokenType.SYMBOL, pos);
            }
            return new Token(token.toString(), TokenType.INTEGER, pos);
        } else if (state == 11 || state == 15) {
            return new Token(token.toString(), TokenType.REAL, pos);
        } else if (state == 14) {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: malformed exponent", new Object[0]));
        } else if (state == 13) {
            return new Token(token.toString(), TokenType.RATIONAL, pos);
        } else if (state == 2) {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: String not closed", new Object[0]));
        } else if (state == 3) {
            String sym = maybeFold(in, token.toString());
            String symLower = sym.toLowerCase();
            if (symLower.equals("+inf.0") || symLower.equals("-inf.0") || symLower.equals("+nan.0"))
                return new Token(symLower, TokenType.REAL, pos);
            return new Token(sym, TokenType.SYMBOL, pos);
        } else if (state == 6 || state == 61) {
            return asCharacterToken(token.toString(), pos);
        } else if (state == 52) {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: Unexpected end of input in datum label", new Object[0]));
        } else if (state == 30 || state == 31 || state == 32) {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: delimited identifier not closed", new Object[0]));
        } else if (state == 53 || state == 54 || state == 55) {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: heredoc not closed", new Object[0]));
        } else if (state == 56) {
            String tv = token.toString();
            if (tv.equals("t") || tv.equals("true")) return new Token("#t", TokenType.TRUE, pos);
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: invalid boolean literal: #" + tv, new Object[0]));
        } else if (state == 57) {
            String fv = token.toString();
            if (fv.equals("f") || fv.equals("false")) return new Token("#f", TokenType.FALSE, pos);
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: invalid boolean literal: #" + fv, new Object[0]));
        } else if (state == 58 || state == 59 || state == 60) {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: block comment not closed", new Object[0]));
        } else {
            throw new SchemeError(in.pos(), new ReadErrorObject("tokenizer: Unexpected end of input", new Object[0]));
        }
    }

    private static void readExactnessPrefix(TextStream in, SourcePos pos, boolean[] forceExactInexact) throws IOException {
        int ec = in.peek();
        in.read();
        char ec2 = Character.toLowerCase((char) ec);
        if (ec2 == 'e') { forceExactInexact[0] = true; forceExactInexact[1] = false; }
        else if (ec2 == 'i') { forceExactInexact[0] = false; forceExactInexact[1] = true; }
        else throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected #e or #i exactness prefix, got #" + (char) ec, new Object[0]));
    }

    private static int prefixToRadix(char ch, SourcePos pos) {
        switch (Character.toLowerCase(ch)) {
            case 'b': return 2;
            case 'o': return 8;
            case 'd': return 10;
            case 'x': return 16;
            default: throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown radix prefix: " + ch, new Object[0]));
        }
    }

    private static boolean isDigitInRadix(char ch, int radix) {
        if (radix <= 10) return ch >= '0' && ch < (char)('0' + radix);
        if (ch >= '0' && ch <= '9') return true;
        char lower = Character.toLowerCase(ch);
        return lower >= 'a' && lower < (char)('a' + radix - 10);
    }

    private static Object parseIntegerInRadix(String s, int radix) {
        try { return Long.parseLong(s, radix); }
        catch (NumberFormatException e) {
            return IntegerMath.normalize(new java.math.BigInteger(s, radix));
        }
    }

    private static long gcd(long a, long b) {
        while (b != 0) { long t = b; b = a % b; a = t; }
        return a;
    }

    private static int trailingZeros64(long n) {
        if (n == 0) return 64;
        int count = 0;
        while ((n & 1L) == 0) { n >>= 1; count++; }
        return count;
    }

    private static Token doubleToExactToken(double d, SourcePos pos) {
        if (Double.isInfinite(d) || Double.isNaN(d))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: #e applied to non-finite number", new Object[0]));
        double absD = Math.abs(d);
        long bits = Double.doubleToLongBits(absD);
        long mant = bits & 0x000FFFFFFFFFFFFFL;
        int biasedExp = (int)((bits >> 52) & 0x7FFL);
        long n;
        int shift;
        if (biasedExp == 0) {
            n = mant;
            shift = 1074;
        } else {
            n = mant | (1L << 52);
            shift = 1023 + 52 - biasedExp;
        }
        if (shift <= 0) {
            long intN = n << (-shift);
            if (d < 0) intN = -intN;
            return new Token(Long.toString(intN), TokenType.INTEGER, pos);
        }
        int tz = trailingZeros64(n);
        int reduce = Math.min(tz, shift);
        n >>= reduce;
        shift -= reduce;
        if (shift > 62) {
            return new Token("0", TokenType.INTEGER, pos);
        }
        long den = 1L << shift;
        if (d < 0) n = -n;
        if (den == 1) return new Token(Long.toString(n), TokenType.INTEGER, pos);
        return new Token(n + "/" + den, TokenType.RATIONAL, pos);
    }

    private static Token readPrefixedNumber(TextStream in, int radix, boolean forceExact, boolean forceInexact, SourcePos pos) throws IOException {
        int sign = 1;
        int c = in.peek();
        if (c == '+') { in.read(); sign = 1; c = in.peek(); }
        else if (c == '-') { in.read(); sign = -1; c = in.peek(); }

        // Check for +inf.0, -inf.0, +nan.0 (after sign)
        if (radix == 10 && (c == 'i' || c == 'I' || c == 'n' || c == 'N')) {
            StringBuilder special = new StringBuilder();
            special.append(sign < 0 ? '-' : '+');
            while (c != -1 && "infINFnanNAN.0".indexOf((char) c) >= 0) {
                special.append((char) c);
                in.read();
                c = in.peek();
            }
            String s = special.toString().toLowerCase();
            if (s.equals("+inf.0")) return new Token("+inf.0", TokenType.REAL, pos);
            if (s.equals("-inf.0")) return new Token("-inf.0", TokenType.REAL, pos);
            if (s.equals("+nan.0")) return new Token("+nan.0", TokenType.REAL, pos);
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid number: " + special, new Object[0]));
        }

        StringBuilder digits = new StringBuilder();
        while (c != -1 && isDigitInRadix((char) c, radix)) {
            digits.append((char) c);
            in.read();
            c = in.peek();
        }
        if (digits.length() == 0 && c != '.')
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected digits in number", new Object[0]));

        Object intVal = digits.length() > 0 ? parseIntegerInRadix(digits.toString(), radix) : (Object) 0L;
        if (sign < 0) intVal = IntegerMath.genericNegate(intVal);

        if (c == '/') {
            in.read();
            c = in.peek();
            StringBuilder denomDigits = new StringBuilder();
            while (c != -1 && isDigitInRadix((char) c, radix)) {
                denomDigits.append((char) c);
                in.read();
                c = in.peek();
            }
            if (denomDigits.length() == 0)
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected denominator after /", new Object[0]));
            Object denomVal = parseIntegerInRadix(denomDigits.toString(), radix);
            if (IntegerMath.isZero(denomVal))
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: division by zero in rational literal", new Object[0]));
            if (forceInexact) {
                double dv = IntegerMath.toDouble(intVal) / IntegerMath.toDouble(denomVal);
                return new Token(Double.toString(dv), TokenType.REAL, pos);
            }
            Object result = Rational.create(intVal, denomVal);
            if (Value.isInteger(result)) return new Token(result.toString(), TokenType.INTEGER, pos);
            Rational r = (Rational) result;
            return new Token(r.toString(), TokenType.RATIONAL, pos);
        }

        if (c == '.' && (radix == 10 || radix == 16)) {
            in.read();
            c = in.peek();
            StringBuilder fracDigits = new StringBuilder();
            while (c != -1 && isDigitInRadix((char) c, radix)) {
                fracDigits.append((char) c);
                in.read();
                c = in.peek();
            }
            String numStr = (sign < 0 ? "-" : "") + digits + "." + (fracDigits.length() > 0 ? fracDigits.toString() : "0");
            if ((c == 'e' || c == 'E') && radix == 10) {
                numStr += 'e';
                in.read(); c = in.peek();
                if (c == '+' || c == '-') { numStr += (char) c; in.read(); c = in.peek(); }
                StringBuilder expDigits = new StringBuilder();
                while (c != -1 && c >= '0' && c <= '9') { expDigits.append((char) c); in.read(); c = in.peek(); }
                numStr += expDigits;
            }
            double dval = Double.parseDouble(numStr);
            if (forceExact) return doubleToExactToken(dval, pos);
            return new Token(Double.toString(dval), TokenType.REAL, pos);
        }

        if ((c == 'e' || c == 'E') && radix == 10) {
            String numStr = (sign < 0 ? "-" : "") + digits + 'e';
            in.read(); c = in.peek();
            if (c == '+' || c == '-') { numStr += (char) c; in.read(); c = in.peek(); }
            StringBuilder expDigits = new StringBuilder();
            while (c != -1 && c >= '0' && c <= '9') { expDigits.append((char) c); in.read(); c = in.peek(); }
            numStr += expDigits;
            double dval = Double.parseDouble(numStr);
            if (forceExact) return doubleToExactToken(dval, pos);
            return new Token(Double.toString(dval), TokenType.REAL, pos);
        }

        if (forceInexact) {
            return new Token(Double.toString(IntegerMath.toDouble(intVal)), TokenType.REAL, pos);
        }
        return new Token(intVal.toString(), TokenType.INTEGER, pos);
    }

    private static boolean isDelimiterOrEnd(int c, String delim) {
        return c == -1 || delim.indexOf((char) c) != -1 || c == ';';
    }

    private static Token readPrefixedNumberOrComplex(TextStream in, int radix, boolean forceExact, boolean forceInexact, SourcePos pos) throws IOException {
        Token token = readPrefixedNumber(in, radix, forceExact, forceInexact, pos);
        int c = in.peek();
        if (c == '+' || c == '-') {
            // Complex continuation: read imaginary part
            return readComplexImaginary(in, token.value, pos);
        }
        if (c == '@') {
            return readPolarForm(in, token.value, pos);
        }
        return token;
    }

    /**
     * After reading the real part of a complex number, reads the imaginary part.
     * in.peek() should be '+' or '-' (the sign of the imaginary part).
     * realPart is the string of the already-parsed real part.
     */
    private static Token readComplexImaginary(TextStream in, String realPart, SourcePos pos) throws IOException {
        String delim = "()[]\"" + " \r\n\t";
        int c = in.peek();
        char sign = (char) c;
        in.read(); // consume the sign
        c = in.peek();

        // Check for +i/-i, +inf.0i/-inf.0i, +nan.0i/-nan.0i
        if (c == 'i' || c == 'I' || c == 'n' || c == 'N') {
            // Try to read "inf.0" or "nan.0" (max 5 chars after sign)
            StringBuilder special = new StringBuilder();
            special.append(sign);
            int maxRead = 5; // "inf.0" or "nan.0" = 5 chars
            int count = 0;
            while (c != -1 && count < maxRead && "infINFnanNAN.0".indexOf((char) c) >= 0) {
                special.append((char) c);
                in.read();
                c = in.peek();
                count++;
            }
            String s = special.toString().toLowerCase();

            // +i or -i (pure imaginary unit)
            if (s.equals("+i") || s.equals("-i")) {
                if (isDelimiterOrEnd(c, delim))
                    return new Token(realPart + "|" + sign + "1", TokenType.COMPLEX, pos);
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", new Object[0]));
            }

            // +inf.0i, -inf.0i, +nan.0i, -nan.0i
            if ((s.equals("+inf.0") || s.equals("-inf.0") || s.equals("+nan.0") || s.equals("-nan.0")) &&
                (c == 'i' || c == 'I')) {
                in.read(); // consume 'i'
                int next = in.peek();
                if (isDelimiterOrEnd(next, delim))
                    return new Token(realPart + "|" + s, TokenType.COMPLEX, pos);
            }
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", new Object[0]));
        }

        // Read imaginary digits
        StringBuilder imagDigits = new StringBuilder();
        imagDigits.append(sign);
        while (c != -1 && c >= '0' && c <= '9') {
            imagDigits.append((char) c);
            in.read();
            c = in.peek();
        }

        if (c == 'i' || c == 'I') {
            in.read();
            int next = in.peek();
            if (isDelimiterOrEnd(next, delim))
                return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", new Object[0]));
        }

        if (c == '/') {
            // Rational imaginary part
            imagDigits.append('/');
            in.read();
            c = in.peek();
            while (c != -1 && c >= '0' && c <= '9') {
                imagDigits.append((char) c);
                in.read();
                c = in.peek();
            }
            if (c == 'i' || c == 'I') {
                in.read();
                int next = in.peek();
                if (isDelimiterOrEnd(next, delim))
                    return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
            }
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", new Object[0]));
        }

        if (c == '.') {
            // Decimal imaginary part
            imagDigits.append('.');
            in.read();
            c = in.peek();
            while (c != -1 && c >= '0' && c <= '9') {
                imagDigits.append((char) c);
                in.read();
                c = in.peek();
            }
        }

        if (c != -1 && isExponentMarker(c)) {
            // Exponent in imaginary part
            imagDigits.append((char) c);
            in.read();
            c = in.peek();
            if (c == '+' || c == '-') {
                imagDigits.append((char) c);
                in.read();
                c = in.peek();
            }
            while (c != -1 && c >= '0' && c <= '9') {
                imagDigits.append((char) c);
                in.read();
                c = in.peek();
            }
        }

        if (c == 'i' || c == 'I') {
            in.read();
            int next = in.peek();
            if (isDelimiterOrEnd(next, delim))
                return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
        }

        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", new Object[0]));
    }

    /**
     * Reads polar form: magnitude already parsed, in.peek() is '@'.
     */
    private static Token readPolarForm(TextStream in, String magnitude, SourcePos pos) throws IOException {
        in.read(); // consume '@'
        // Read the angle as a full number
        Token angleToken = readPrefixedNumber(in, 10, false, false, pos);
        // Return as COMPLEX with polar conversion marker
        return new Token(magnitude + "@" + angleToken.value, TokenType.COMPLEX, pos);
    }

    private static Token asCharacterToken(String result, SourcePos pos) {
        if (result.equals("newline")) {
            result = "\n";
        } else if (result.equals("return")) {
            result = "\r";
        } else if (result.equals("space")) {
            result = " ";
        } else if (result.equals("tab")) {
            result = "\t";
        } else if (result.equals("alarm")) {
            result = "\u0007";
        } else if (result.equals("backspace")) {
            result = "\u0008";
        } else if (result.equals("delete")) {
            result = "\u007F";
        } else if (result.equals("escape")) {
            result = "\u001B";
        } else if (result.equals("null")) {
            result = "\u0000";
        } else if (result.matches("x[0-9a-fA-F]+")) {
            int codepoint = Integer.parseInt(result.substring(1), 16);
            result = new String(Character.toChars(codepoint));
        } else if (result.length() != 1) {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown character name: " + result, new Object[0]));
        }
        return new Token(result, TokenType.CHARACTER, pos);
    }
}
