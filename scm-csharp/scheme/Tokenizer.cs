using System.Text.RegularExpressions;
using System.Text;

namespace scheme;

public class Tokenizer
{
    private static string Maybefold(TextStream reader, string s) =>
        reader.FoldCase ? s.ToLowerInvariant() : s;

    // R7RS exponent markers: e (default), s (short), f (single), d (double), l (long)
    private static bool IsExponentMarker(int ch) =>
        ch == 'e' || ch == 'E' || ch == 's' || ch == 'S' ||
        ch == 'f' || ch == 'F' || ch == 'd' || ch == 'D' ||
        ch == 'l' || ch == 'L';

    public static Token? ReadToken(TextStream reader)
    {
        string whitespace = " \r\n\t";
        string delim = "()[]\"" + whitespace;
        int c = reader.Peek();
        int state = 0;
        int nestDepth = 0;
        StringBuilder token = new StringBuilder();
        StringBuilder? hexBuf = null;
        StringBuilder? heredocMarker = null;
        StringBuilder? lineBuffer = null;
        bool putback = false;
	SourcePos pos = reader.Pos();
        while (c != -1)
        {
            char ch = (char) c;
            switch (state)
            {
                case 0: // whitespace or single char token
		    pos = reader.Pos();
                    if (ch == '(' || ch == '[')
                    {
                        reader.Read();
                        return new Token("(", TokenType.OPENPAR, pos);
                    }
                    else if (ch == ')' || ch == ']')
                    {
                        reader.Read();
                        return new Token(")", TokenType.CLOSEPAR, pos);
                    }
                    else if (ch == '\'')
                    {
			reader.Read();
                        return new Token("'", TokenType.QUOTE, pos);
                    }
                    else if (ch == '`')
                    {
                        reader.Read();
                        return new Token("`", TokenType.BACKQUOTE, pos);
                    }
                    else if (ch == ',')
                    {
                        state = 4; // unquote, unquote-splicing
			pos = reader.Pos();
                    }
                    else if (ch == '.')
                    {
                        state = 12; // either dot or real
                        token.Append(ch);
                    }
                    else if (ch == ';')
                    {
                        state = 7; // comment
                    }
                    else if (whitespace.IndexOf(ch) != -1)
                    {
                        break;
                    }
                    else if (('0' <= ch && ch <= '9') || ch == '+' || ch == '-')
                    {
                        state = 1; // number, +, -
                        token.Append(ch);
                    }
                    else if (ch == '\"')
                    {
                        state = 2; // string
                    }
                    else if (ch == '#')
                    {
                        state = 5; // sharp stuff
                    }
                    else if (ch == '|')
                    {
                        state = 30; // delimited identifier |...|
                    }
                    else
                    {
                        state = 3; // symbol
                        token.Append(ch);
                    }
                    break;

                case 1: // number, +,  -
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                    }
                    else if (ch == '.')
                    {
                        token.Append(ch);
                        state = 11; // real
                    }
                    else if (ch == '/')
                    {
                        token.Append(ch);
                        state = 13; // rational denominator
                    }
                    else if (IsExponentMarker(ch))
                    {
                        token.Append(ch);
                        state = 14; // exponent
                    }
                    else if (delim.IndexOf(ch) != -1)
                    {
                        putback = true;
                        if (token.ToString().Equals("+"))
                        {
                            return new Token(Maybefold(reader, "+"), TokenType.SYMBOL, pos);
                        }
                        else if (token.ToString().Equals("-"))
                        {
                            return new Token(Maybefold(reader, "-"), TokenType.SYMBOL, pos);
                        }
                        else
                        {
                            return new Token(token.ToString(), TokenType.INTEGER, pos);
                        }
                    }
                    else if ((ch == '+' || ch == '-') && token.Length > 0 &&
                             !(token.Length == 1 && (token[0] == '+' || token[0] == '-')))
                    {
                        // Complex number: real part is integer, imaginary follows
                        return ReadComplexImaginary(reader, token.ToString(), pos);
                    }
                    else if ((ch == 'i' || ch == 'I') && token.Length > 0 &&
                             (token[0] == '+' || token[0] == '-'))
                    {
                        // Pure imaginary: +Ni, -Ni, +i, -i
                        // Speculatively consume 'i' to check delimiter
                        reader.Read();
                        int next = reader.Peek();
                        if (IsDelimiterOrEnd(next, delim))
                        {
                            string imagStr = token.ToString();
                            if (imagStr == "+" || imagStr == "-")
                                imagStr += "1";
                            return new Token("0|" + imagStr, TokenType.COMPLEX, pos);
                        }
                        // Not pure imaginary — continue as symbol
                        // 'i' was already consumed, update c and use putback
                        token.Append('i');
                        state = 3;
                        c = reader.Peek();
                        putback = true;
                        break;
                    }
                    else if (ch == '@' && token.Length > 0 &&
                             !(token.Length == 1 && (token[0] == '+' || token[0] == '-')))
                    {
                        return ReadPolarForm(reader, token.ToString(), pos);
                    }
                    else
                    {
                        token.Append(ch);
                        state = 3; // symbol
                    }
                    break;

                case 13: // rational denominator (e.g. "1/3")
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                    }
                    else if (ch == '+' || ch == '-')
                    {
                        return ReadComplexImaginary(reader, token.ToString(), pos);
                    }
                    else if ((ch == 'i' || ch == 'I') && (token[0] == '+' || token[0] == '-'))
                    {
                        // Pure imaginary rational: +3/4i
                        reader.Read();
                        int next = reader.Peek();
                        if (IsDelimiterOrEnd(next, delim))
                        {
                            return new Token("0|" + token.ToString(), TokenType.COMPLEX, pos);
                        }
                        token.Append('i');
                        state = 3;
                        c = reader.Peek();
                        putback = true;
                        break;
                    }
                    else if (ch == '@')
                    {
                        return ReadPolarForm(reader, token.ToString(), pos);
                    }
                    else
                    {
                        putback = true;
                        return new Token(token.ToString(), TokenType.RATIONAL, pos);
                    }
                    break;

                case 11: // real
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                    }
                    else if (IsExponentMarker(ch))
                    {
                        token.Append(ch);
                        state = 14; // exponent
                    }
                    else
                    {
                        string rtok = token.ToString();
                        if (rtok.Equals("+."))
                        {
                            putback = true;
                            return new Token(Maybefold(reader, "+"), TokenType.SYMBOL, pos);
                        }
                        else if (rtok.Equals("-."))
                        {
                            putback = true;
                            return new Token(Maybefold(reader, "-"), TokenType.SYMBOL, pos);
                        }
                        else if (ch == '+' || ch == '-')
                        {
                            return ReadComplexImaginary(reader, rtok, pos);
                        }
                        else if ((ch == 'i' || ch == 'I') && (rtok[0] == '+' || rtok[0] == '-'))
                        {
                            reader.Read();
                            int next = reader.Peek();
                            if (IsDelimiterOrEnd(next, delim))
                                return new Token("0|" + rtok, TokenType.COMPLEX, pos);
                            token.Append('i');
                            state = 3;
                            c = reader.Peek();
                            putback = true;
                            break;
                        }
                        else if (ch == '@')
                        {
                            return ReadPolarForm(reader, rtok, pos);
                        }
                        else
                        {
                            putback = true;
                            return new Token(rtok, TokenType.REAL, pos);
                        }
                    }
                    break;

                case 14: // seen e/E, awaiting optional sign or first exponent digit
                    if (ch == '+' || ch == '-' || ('0' <= ch && ch <= '9'))
                    {
                        token.Append(ch);
                        state = 15;
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed exponent", Array.Empty<object>()));
                    }
                    break;

                case 15: // accumulating exponent digits
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                    }
                    else if (ch == '+' || ch == '-')
                    {
                        return ReadComplexImaginary(reader, token.ToString(), pos);
                    }
                    else if (ch == '@')
                    {
                        return ReadPolarForm(reader, token.ToString(), pos);
                    }
                    else
                    {
                        putback = true;
                        return new Token(token.ToString(), TokenType.REAL, pos);
                    }
                    break;

                case 12: // dot or real
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                        state = 11;
                    }
                    else if (ch == '.')
                    {
                        // ".." or "..." — treat as symbol (R7RS identifiers)
                        token.Append(ch);
                        state = 3;
                    }
                    else
                    {
                        putback = true;
                        return new Token(".", TokenType.DOT, pos);
                    }
                    break;

                case 2: // string
                    if (ch == '\\')
                    {
                        state = 21; // string escape
                    }
                    else if (ch == '\"')
                    {
                        reader.Read();
                        return new Token(token.ToString(), TokenType.STRING, pos);
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 21: // string escape
                    if (ch == '"' || ch == '\\')
                    {
                        token.Append(ch);
                        state = 2;
                    }
                    else if (ch == 'n')
                    {
                        token.Append('\n');
                        state = 2;
                    }
                    else if (ch == 'r')
                    {
                        token.Append('\r');
                        state = 2;
                    }
                    else if (ch == 't')
                    {
                        token.Append('\t');
                        state = 2;
                    }
                    else if (ch == 'a')
                    {
                        token.Append('\a');
                        state = 2;
                    }
                    else if (ch == 'b')
                    {
                        token.Append('\b');
                        state = 2;
                    }
                    else if (ch == '|')
                    {
                        token.Append('|');
                        state = 2;
                    }
                    else if (ch == '0')
                    {
                        token.Append('\0');
                        state = 2;
                    }
                    else if (ch == 'x')
                    {
                        hexBuf = hexBuf ?? new StringBuilder();
                        hexBuf.Clear();
                        state = 22;
                    }
                    else if (ch == ' ' || ch == '\t')
                    {
                        state = 23; // skip intraline whitespace before line ending
                    }
                    else if (ch == '\n')
                    {
                        state = 25; // saw \n, skip trailing intraline whitespace only
                    }
                    else if (ch == '\r')
                    {
                        state = 24; // saw \r, may need to consume \n of \r\n
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid string escape: \\" + ch, Array.Empty<object>()));
                    }
                    break;

                case 22: // hex string escape \xNNN;
                    if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'))
                    {
                        hexBuf!.Append(ch);
                    }
                    else if (ch == ';')
                    {
                        if (hexBuf!.Length == 0)
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: empty hex escape \\x;", Array.Empty<object>()));
                        int codepoint = int.Parse(hexBuf.ToString(), System.Globalization.NumberStyles.HexNumber);
                        token.Append(char.ConvertFromUtf32(codepoint));
                        state = 2;
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed hex escape", Array.Empty<object>()));
                    }
                    break;

                case 23: // line continuation — skip intraline whitespace before line ending
                    if (ch == ' ' || ch == '\t')
                    {
                        // skip, stay in 23
                    }
                    else if (ch == '\n')
                    {
                        state = 25; // saw \n, skip trailing intraline whitespace only
                    }
                    else if (ch == '\r')
                    {
                        state = 24; // saw \r, may need to consume \n of \r\n
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid string escape: expected newline in line continuation", Array.Empty<object>()));
                    }
                    break;

                case 24: // line continuation — saw \r, may need to consume \n of \r\n
                    if (ch == '\n')
                    {
                        // consume the \n of \r\n, then skip trailing intraline whitespace
                        state = 25;
                    }
                    else if (ch == ' ' || ch == '\t')
                    {
                        // no \n after \r; skip trailing intraline whitespace
                        state = 25;
                    }
                    else
                    {
                        putback = true;
                        state = 2;
                    }
                    break;

                case 25: // line continuation — skip trailing intraline whitespace only
                    if (ch == ' ' || ch == '\t')
                    {
                        // skip intraline whitespace, stay in 25
                    }
                    else
                    {
                        putback = true;
                        state = 2;
                    }
                    break;

                case 3: // symbol
                    if (delim.IndexOf(ch) != -1)
                    {
                        putback = true;
                        string sym = Maybefold(reader, token.ToString());
                        var symLower = sym.ToLowerInvariant();
                        if (symLower == "+inf.0" || symLower == "-inf.0" || symLower == "+nan.0")
                            return new Token(symLower, TokenType.REAL, pos);
                        return new Token(sym, TokenType.SYMBOL, pos);
                    }
                    else if ((ch == '+' || ch == '-') && token.Length >= 5)
                    {
                        var symLower = token.ToString().ToLowerInvariant();
                        if (symLower == "+inf.0" || symLower == "-inf.0" || symLower == "+nan.0")
                            return ReadComplexImaginary(reader, symLower, pos);
                        token.Append(ch);
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 4: // unquote, unquote-splicing
                    if (ch == '@')
                    {
                        reader.Read();
                        return new Token(",@", TokenType.COMMAAT, pos);
                    }
                    else
                    {
                        putback = true;
                        return new Token(",", TokenType.COMMA, pos);
                    }

                case 5: // sharp stuff
                    if (ch == 't')
                    {
                        token.Append(ch);
                        state = 56; // reading #t or #true
                    }
                    else if (ch == 'f')
                    {
                        token.Append(ch);
                        state = 57; // reading #f or #false
                    }
                    else if (ch == '(')
                    {
                        reader.Read();
                        return new Token("#(", TokenType.SHARPOPENPAR, pos);
                    }
                    else if (ch == ';')
                    {
                        reader.Read();
                        return new Token("#;", TokenType.DATUMCOMMENT, pos);
                    }
                    else if (ch == '|')
                    {
                        nestDepth = 1;
                        state = 58; // block comment
                    }
                    else if (ch == 'u')
                    {
                        state = 50; // #u...
                    }
                    else if (ch == '\\')
                    {
                        state = 6; // character
                    }
                    else if ('0' <= ch && ch <= '9')
                    {
                        state = 52; // datum label #N= or #N#
                        token.Append(ch);
                    }
                    else if (ch == '<')
                    {
                        state = 53; // heredoc: expect second <
                    }
                    else if (ch == 'b' || ch == 'B')
                    {
                        reader.Read();
                        bool fx2 = false, ix2 = false;
                        if (reader.Peek() == '#') { reader.Read(); ReadExactnessPrefix(reader, pos, out fx2, out ix2); }
                        return ReadPrefixedNumberOrComplex(reader, 2, fx2, ix2, pos);
                    }
                    else if (ch == 'o' || ch == 'O')
                    {
                        reader.Read();
                        bool fx2 = false, ix2 = false;
                        if (reader.Peek() == '#') { reader.Read(); ReadExactnessPrefix(reader, pos, out fx2, out ix2); }
                        return ReadPrefixedNumberOrComplex(reader, 8, fx2, ix2, pos);
                    }
                    else if (ch == 'x' || ch == 'X')
                    {
                        reader.Read();
                        bool fx2 = false, ix2 = false;
                        if (reader.Peek() == '#') { reader.Read(); ReadExactnessPrefix(reader, pos, out fx2, out ix2); }
                        return ReadPrefixedNumberOrComplex(reader, 16, fx2, ix2, pos);
                    }
                    else if (ch == 'd' || ch == 'D')
                    {
                        reader.Read();
                        bool fx2 = false, ix2 = false;
                        if (reader.Peek() == '#') { reader.Read(); ReadExactnessPrefix(reader, pos, out fx2, out ix2); }
                        return ReadPrefixedNumberOrComplex(reader, 10, fx2, ix2, pos);
                    }
                    else if (ch == 'e' || ch == 'E')
                    {
                        reader.Read();
                        int peeked = reader.Peek();
                        if (peeked == '#')
                        {
                            reader.Read(); // consume second '#'
                            int radixCh = reader.Peek();
                            reader.Read(); // consume radix char
                            int r2 = PrefixToRadix((char)radixCh, pos);
                            return ReadPrefixedNumberOrComplex(reader, r2, true, false, pos);
                        }
                        return ReadPrefixedNumberOrComplex(reader, 10, true, false, pos);
                    }
                    else if (ch == 'i' || ch == 'I')
                    {
                        reader.Read();
                        int peeked = reader.Peek();
                        if (peeked == '#')
                        {
                            reader.Read(); // consume second '#'
                            int radixCh = reader.Peek();
                            reader.Read(); // consume radix char
                            int r2 = PrefixToRadix((char)radixCh, pos);
                            return ReadPrefixedNumberOrComplex(reader, r2, false, true, pos);
                        }
                        return ReadPrefixedNumberOrComplex(reader, 10, false, true, pos);
                    }
                    else if (ch == '\'')
                    {
                        reader.Read();
                        return new Token("#'", TokenType.SYNTAX, pos);
                    }
                    else if (ch == '`')
                    {
                        reader.Read();
                        return new Token("#`", TokenType.QUASISYNTAX, pos);
                    }
                    else if (ch == ',')
                    {
                        reader.Read(); // consume ','
                        int next = reader.Peek();
                        if (next == '@')
                        {
                            reader.Read(); // consume '@'
                            return new Token("#,@", TokenType.UNSYNTAXSPLICING, pos);
                        }
                        return new Token("#,", TokenType.UNSYNTAX, pos);
                    }
                    else if (ch == '!')
                    {
                        reader.Read(); // consume '!'
                        // Shebang line: #!/ treated as line comment (R6RS §4.2.1)
                        if (reader.Peek() == '/')
                        {
                            int sc = reader.Peek();
                            while (sc != -1 && sc != '\n')
                            {
                                reader.Read();
                                sc = reader.Peek();
                            }
                            token.Clear();
                            state = 0;
                            c = reader.Peek();
                            continue;
                        }
                        StringBuilder directive = new StringBuilder();
                        int dc = reader.Peek();
                        while (dc != -1 && "()[]\" \r\n\t".IndexOf((char)dc) == -1)
                        {
                            directive.Append((char)dc);
                            reader.Read();
                            dc = reader.Peek();
                        }
                        string dir = directive.ToString().ToLowerInvariant();
                        if (dir == "fold-case")
                        {
                            reader.FoldCase = true;
                        }
                        else if (dir == "no-fold-case")
                        {
                            reader.FoldCase = false;
                        }
                        else
                        {
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown directive: #!" + directive, Array.Empty<object>()));
                        }
                        token.Clear();
                        state = 0;
                        c = reader.Peek();
                        continue;
                    }
                    else
                    {
                        reader.Read();
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence: #" + ch, Array.Empty<object>()));
                    }
                    break;

                case 56: // reading #t or #true
                    if (delim.IndexOf(ch) != -1)
                    {
                        putback = true;
                        string tv = token.ToString();
                        if (tv == "t" || tv == "true")
                            return new Token("#t", TokenType.TRUE, pos);
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid boolean literal: #" + tv, Array.Empty<object>()));
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 57: // reading #f or #false
                    if (delim.IndexOf(ch) != -1)
                    {
                        putback = true;
                        string fv = token.ToString();
                        if (fv == "f" || fv == "false")
                            return new Token("#f", TokenType.FALSE, pos);
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid boolean literal: #" + fv, Array.Empty<object>()));
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 58: // block comment body
                    if (ch == '|') state = 59;
                    else if (ch == '#') state = 60;
                    // else stay in 58
                    break;

                case 59: // block comment: previous char was '|'
                    if (ch == '#')
                    {
                        nestDepth--;
                        if (nestDepth == 0)
                        {
                            // End of block comment — restart from state 0
                            token.Clear();
                            state = 0;
                        }
                        else
                        {
                            state = 58;
                        }
                    }
                    else if (ch == '|') { /* stay in 59 */ }
                    else state = 58;
                    break;

                case 60: // block comment: previous char was '#'
                    if (ch == '|') { nestDepth++; state = 58; }
                    else if (ch == '#') { /* stay in 60 */ }
                    else state = 58;
                    break;

                case 52: // accumulating label number after #
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                        break;
                    }
                    if (ch == '=')
                    {
                        reader.Read();
                        return new Token(token.ToString(), TokenType.LABELDEFINITION, pos);
                    }
                    if (ch == '#')
                    {
                        reader.Read();
                        return new Token(token.ToString(), TokenType.LABELREFERENCE, pos);
                    }
                    throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed datum label", Array.Empty<object>()));

                case 50: // #u...
                    if (ch == '8')
                    {
                        state = 51; // #u8...
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence", Array.Empty<object>()));
                    }
                    break;

                case 51: // #u8...
                    if (ch == '(')
                    {
                        reader.Read();
                        return new Token("#u8(", TokenType.BYTEVECTOROPENPAR, pos);
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: Unknown # sequence", Array.Empty<object>()));
                    }

                case 6: // character
		    token.Append(ch);
                    state = 61;
                    break;

                case 61: // character
                    if (delim.IndexOf(ch) != -1)
                    {
                        putback = true;
                        return AsCharacterToken(token.ToString(), pos);
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 53: // heredoc: second <
                    if (ch == '<')
                    {
                        state = 54; // now read marker name
                        heredocMarker = heredocMarker ?? new StringBuilder();
                        heredocMarker.Clear();
                    }
                    else
                    {
                        reader.Read();
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected #<< for heredoc", Array.Empty<object>()));
                    }
                    break;

                case 54: // reading heredoc marker name
                    if (ch == '\r') break; // skip CR
                    if (ch == '\n')
                    {
                        state = 55; // start reading body
                        lineBuffer = lineBuffer ?? new StringBuilder();
                        lineBuffer.Clear();
                    }
                    else
                    {
                        heredocMarker!.Append(ch);
                    }
                    break;

                case 55: // reading heredoc body
                    if (ch == '\r') break; // skip CR
                    if (ch == '\n')
                    {
                        if (lineBuffer!.ToString() == heredocMarker!.ToString())
                        {
                            reader.Read();
                            return new Token(token.ToString(), TokenType.STRING, pos);
                        }
                        token.Append(lineBuffer);
                        token.Append('\n');
                        lineBuffer.Clear();
                    }
                    else
                    {
                        lineBuffer!.Append(ch);
                    }
                    break;

                case 30: // delimited identifier |...|
                    if (ch == '|')
                    {
                        reader.Read();
                        return new Token(token.ToString(), TokenType.SYMBOL, pos);
                    }
                    else if (ch == '\\')
                    {
                        state = 31; // escape inside delimited identifier
                    }
                    else
                    {
                        token.Append(ch);
                    }
                    break;

                case 31: // escape inside delimited identifier
                    if (ch == 'x')
                    {
                        hexBuf = hexBuf ?? new StringBuilder();
                        hexBuf.Clear();
                        state = 32;
                    }
                    else if (ch == '\\' || ch == '|')
                    {
                        token.Append(ch);
                        state = 30;
                    }
                    else if (ch == 'a')
                    {
                        token.Append('\a');
                        state = 30;
                    }
                    else if (ch == 'b')
                    {
                        token.Append('\b');
                        state = 30;
                    }
                    else if (ch == 'n')
                    {
                        token.Append('\n');
                        state = 30;
                    }
                    else if (ch == 'r')
                    {
                        token.Append('\r');
                        state = 30;
                    }
                    else if (ch == 't')
                    {
                        token.Append('\t');
                        state = 30;
                    }
                    else if (ch == '"')
                    {
                        token.Append('"');
                        state = 30;
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid escape in delimited identifier: \\" + ch, Array.Empty<object>()));
                    }
                    break;

                case 32: // hex escape inside delimited identifier \xNNN;
                    if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'))
                    {
                        hexBuf!.Append(ch);
                    }
                    else if (ch == ';')
                    {
                        if (hexBuf!.Length == 0)
                            throw new SchemeError(pos, new ReadErrorObject("tokenizer: empty hex escape \\x;", Array.Empty<object>()));
                        int codepoint = int.Parse(hexBuf.ToString(), System.Globalization.NumberStyles.HexNumber);
                        token.Append(char.ConvertFromUtf32(codepoint));
                        state = 30;
                    }
                    else
                    {
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed hex escape in delimited identifier", Array.Empty<object>()));
                    }
                    break;

                case 7: // comment
                    if (ch == '\n') state = 0;
		    pos = reader.Pos();
                    break;
            }
            if (!putback)
            {
                reader.Read();
                c = reader.Peek();
            }
            else
            {
                putback = false;
            }
        }
        if (state == 0 && (token == null || token.Length == 0)) return null;
        if (state == 1)
        {
            if (token.ToString().Equals("+") || token.ToString().Equals("-"))
            {
                return new Token(Maybefold(reader, token.ToString()), TokenType.SYMBOL, pos);
            }
            return new Token(token.ToString(), TokenType.INTEGER, pos);
        }
        else if (state == 11 || state == 15)
        {
            return new Token(token.ToString(), TokenType.REAL, pos);
        }
        else if (state == 14)
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: malformed exponent", Array.Empty<object>()));
        }
        else if (state == 13)
        {
            return new Token(token.ToString(), TokenType.RATIONAL, pos);
        }
        else if (state == 2)
        {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: String not closed", Array.Empty<object>()));
        }
        else if (state == 3)
        {
            string sym = Maybefold(reader, token.ToString());
            var symLower = sym.ToLowerInvariant();
            if (symLower == "+inf.0" || symLower == "-inf.0" || symLower == "+nan.0")
                return new Token(symLower, TokenType.REAL, pos);
            return new Token(sym, TokenType.SYMBOL, pos);
        }
        else if (state == 6 || state == 61)
        {
            return AsCharacterToken(token.ToString(), pos);
        }
        else if (state == 52)
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: Unexpected end of input in datum label", Array.Empty<object>()));
        }
        else if (state == 30 || state == 31 || state == 32)
        {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: delimited identifier not closed", Array.Empty<object>()));
        }
        else if (state == 53 || state == 54 || state == 55)
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: heredoc not closed", Array.Empty<object>()));
        }
        else if (state == 56)
        {
            string tv = token.ToString();
            if (tv == "t" || tv == "true") return new Token("#t", TokenType.TRUE, pos);
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: invalid boolean literal: #" + tv, Array.Empty<object>()));
        }
        else if (state == 57)
        {
            string fv = token.ToString();
            if (fv == "f" || fv == "false") return new Token("#f", TokenType.FALSE, pos);
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: invalid boolean literal: #" + fv, Array.Empty<object>()));
        }
        else if (state == 58 || state == 59 || state == 60)
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: block comment not closed", Array.Empty<object>()));
        }
        else
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: Unexpected end of input", Array.Empty<object>()));
        }
    }

    private static void ReadExactnessPrefix(TextStream reader, SourcePos pos, out bool forceExact, out bool forceInexact)
    {
        int ec = reader.Peek();
        reader.Read();
        char ec2 = char.ToLower((char)ec);
        if (ec2 == 'e') { forceExact = true; forceInexact = false; }
        else if (ec2 == 'i') { forceExact = false; forceInexact = true; }
        else throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected #e or #i exactness prefix, got #" + (char)ec, Array.Empty<object>()));
    }

    private static int PrefixToRadix(char ch, SourcePos pos)
    {
        return char.ToLower(ch) switch {
            'b' => 2, 'o' => 8, 'd' => 10, 'x' => 16,
            _ => throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown radix prefix: " + ch, Array.Empty<object>()))
        };
    }

    private static bool IsDigitInRadix(char ch, int radix)
    {
        if (radix <= 10) return ch >= '0' && ch < (char)('0' + radix);
        if (ch >= '0' && ch <= '9') return true;
        char lower = char.ToLower(ch);
        return lower >= 'a' && lower < (char)('a' + radix - 10);
    }

    private static object ParseIntegerInRadix(string s, int radix)
    {
        try { return Convert.ToInt64(s, radix); }
        catch (OverflowException)
        {
            System.Numerics.BigInteger val = System.Numerics.BigInteger.Zero;
            foreach (char c in s)
            {
                int d = c >= '0' && c <= '9' ? c - '0' :
                        c >= 'a' && c <= 'f' ? c - 'a' + 10 :
                        c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                if (d < 0) throw new FormatException();
                val = val * radix + d;
            }
            return IntegerMath.Normalize(val);
        }
    }

    private static long Gcd(long a, long b)
    {
        while (b != 0) { long t = b; b = a % b; a = t; }
        return a;
    }

    private static int TrailingZeros64(long n)
    {
        if (n == 0) return 64;
        int count = 0;
        while ((n & 1L) == 0) { n >>= 1; count++; }
        return count;
    }

    private static Token DoubleToExactToken(double d, SourcePos pos)
    {
        if (double.IsInfinity(d) || double.IsNaN(d))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: #e applied to non-finite number", Array.Empty<object>()));
        double absD = Math.Abs(d);
        long bits = BitConverter.DoubleToInt64Bits(absD);
        long mant = bits & 0x000FFFFFFFFFFFFFL;
        int biasedExp = (int)((bits >> 52) & 0x7FF);
        long n;
        int shift;
        if (biasedExp == 0)
        {
            // subnormal: value = mant * 2^(-1074)
            n = mant;
            shift = 1074;
        }
        else
        {
            // normal: value = (mant | 2^52) * 2^(biasedExp - 1023 - 52)
            n = mant | (1L << 52);
            shift = 1023 + 52 - biasedExp; // denominator = 2^shift
        }
        if (shift <= 0)
        {
            // integer
            long intN = n << (-shift);
            if (d < 0) intN = -intN;
            return new Token(intN.ToString(), TokenType.INTEGER, pos);
        }
        // Reduce by trailing zeros
        int tz = TrailingZeros64(n);
        int reduce = Math.Min(tz, shift);
        n >>= reduce;
        shift -= reduce;
        if (shift > 62)
        {
            // Very large denominator (subnormals) — treat as 0
            return new Token("0", TokenType.INTEGER, pos);
        }
        long den = 1L << shift;
        if (d < 0) n = -n;
        if (den == 1) return new Token(n.ToString(), TokenType.INTEGER, pos);
        return new Token(n + "/" + den, TokenType.RATIONAL, pos);
    }

    private static Token ReadPrefixedNumberOrComplex(TextStream reader, int radix, bool forceExact, bool forceInexact, SourcePos pos)
    {
        Token token = ReadPrefixedNumber(reader, radix, forceExact, forceInexact, pos);
        int c = reader.Peek();
        if (c == '+' || c == '-')
        {
            // Complex continuation: read imaginary part
            return ReadComplexImaginary(reader, token.value, pos);
        }
        if (c == '@')
        {
            return ReadPolarForm(reader, token.value, pos);
        }
        return token;
    }

    private static Token ReadPrefixedNumber(TextStream reader, int radix, bool forceExact, bool forceInexact, SourcePos pos)
    {
        // Read optional sign
        int sign = 1;
        int c = reader.Peek();
        if (c == '+') { reader.Read(); sign = 1; c = reader.Peek(); }
        else if (c == '-') { reader.Read(); sign = -1; c = reader.Peek(); }

        // Check for +inf.0, -inf.0, +nan.0 (after sign)
        if (radix == 10 && (c == 'i' || c == 'I' || c == 'n' || c == 'N'))
        {
            StringBuilder special = new StringBuilder();
            special.Append(sign < 0 ? '-' : '+');
            while (c != -1 && "infINFnanNAN.0".IndexOf((char)c) >= 0)
            {
                special.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            string s = special.ToString().ToLowerInvariant();
            if (s == "+inf.0") return new Token("+inf.0", TokenType.REAL, pos);
            if (s == "-inf.0") return new Token("-inf.0", TokenType.REAL, pos);
            if (s == "+nan.0") return new Token("+nan.0", TokenType.REAL, pos);
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid number: " + special, Array.Empty<object>()));
        }

        // Read integer digits
        StringBuilder digits = new StringBuilder();
        while (c != -1 && IsDigitInRadix((char)c, radix))
        {
            digits.Append((char)c);
            reader.Read();
            c = reader.Peek();
        }

        if (digits.Length == 0 && c != '.')
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected digits in number", Array.Empty<object>()));

        object intVal = digits.Length > 0 ? ParseIntegerInRadix(digits.ToString(), radix) : (object)0L;
        if (sign < 0) intVal = IntegerMath.GenericNegate(intVal);

        // Rational: check for '/'
        if (c == '/')
        {
            reader.Read();
            c = reader.Peek();
            StringBuilder denomDigits = new StringBuilder();
            while (c != -1 && IsDigitInRadix((char)c, radix))
            {
                denomDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            if (denomDigits.Length == 0)
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected denominator after /", Array.Empty<object>()));
            object denomVal = ParseIntegerInRadix(denomDigits.ToString(), radix);
            if (IntegerMath.IsZero(denomVal))
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: division by zero in rational literal", Array.Empty<object>()));
            if (forceInexact)
            {
                double dv = IntegerMath.ToDouble(intVal) / IntegerMath.ToDouble(denomVal);
                return new Token(dv.ToString("G17", System.Globalization.CultureInfo.InvariantCulture), TokenType.REAL, pos);
            }
            object result = Rational.Create(intVal, denomVal);
            if (Value.IsInteger(result)) return new Token(result.ToString()!, TokenType.INTEGER, pos);
            Rational r = (Rational)result;
            return new Token(r.ToString(), TokenType.RATIONAL, pos);
        }

        // Real: check for '.' (decimal/hex only)
        if (c == '.' && (radix == 10 || radix == 16))
        {
            reader.Read();
            c = reader.Peek();
            StringBuilder fracDigits = new StringBuilder();
            while (c != -1 && IsDigitInRadix((char)c, radix))
            {
                fracDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            string numStr = (sign < 0 ? "-" : "") + digits + "." + (fracDigits.Length > 0 ? fracDigits.ToString() : "0");
            // Check for exponent
            if ((c == 'e' || c == 'E') && radix == 10)
            {
                numStr += 'e';
                reader.Read(); c = reader.Peek();
                if (c == '+' || c == '-') { numStr += (char)c; reader.Read(); c = reader.Peek(); }
                StringBuilder expDigits = new StringBuilder();
                while (c != -1 && c >= '0' && c <= '9') { expDigits.Append((char)c); reader.Read(); c = reader.Peek(); }
                numStr += expDigits;
            }
            double dval = double.Parse(numStr, System.Globalization.CultureInfo.InvariantCulture);
            if (forceExact) return DoubleToExactToken(dval, pos);
            return new Token(dval.ToString("G17", System.Globalization.CultureInfo.InvariantCulture), TokenType.REAL, pos);
        }

        // Exponent on integer (decimal only)
        if ((c == 'e' || c == 'E') && radix == 10)
        {
            string numStr = (sign < 0 ? "-" : "") + digits + 'e';
            reader.Read(); c = reader.Peek();
            if (c == '+' || c == '-') { numStr += (char)c; reader.Read(); c = reader.Peek(); }
            StringBuilder expDigits = new StringBuilder();
            while (c != -1 && c >= '0' && c <= '9') { expDigits.Append((char)c); reader.Read(); c = reader.Peek(); }
            numStr += expDigits;
            double dval = double.Parse(numStr, System.Globalization.CultureInfo.InvariantCulture);
            if (forceExact) return DoubleToExactToken(dval, pos);
            return new Token(dval.ToString("G17", System.Globalization.CultureInfo.InvariantCulture), TokenType.REAL, pos);
        }

        // Plain integer
        if (forceInexact)
        {
            double dv = IntegerMath.ToDouble(intVal);
            return new Token(dv.ToString("G17", System.Globalization.CultureInfo.InvariantCulture), TokenType.REAL, pos);
        }
        return new Token(intVal.ToString()!, TokenType.INTEGER, pos);
    }

    private static Token AsCharacterToken(string result, SourcePos pos)
    {
        if (result.Equals("newline"))
            result = "\n";
        else if (result.Equals("return"))
            result = "\r";
        else if (result.Equals("space"))
            result = " ";
        else if (result.Equals("tab"))
            result = "\t";
        else if (result.Equals("alarm"))
            result = "\a";
        else if (result.Equals("backspace"))
            result = "\b";
        else if (result.Equals("delete"))
            result = "\x7F";
        else if (result.Equals("escape"))
            result = "\x1B";
        else if (result.Equals("null"))
            result = "\0";
        else if (Regex.IsMatch(result, @"^x[0-9a-fA-F]+$", RegexOptions.IgnoreCase, Regex.InfiniteMatchTimeout))
        {
            int codepoint = int.Parse(result.Substring(1), System.Globalization.NumberStyles.HexNumber);
            result = char.ConvertFromUtf32(codepoint);
        }
        else if (result.Length != 1)
        {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: unknown character name: " + result, Array.Empty<object>()));
        }
        return new Token(result, TokenType.CHARACTER, pos);
    }

    private static bool IsDelimiterOrEnd(int c, string delim)
    {
        return c == -1 || delim.IndexOf((char)c) != -1 || c == ';';
    }

    /// <summary>
    /// After reading the real part of a complex number, reads the imaginary part.
    /// reader.Peek() should be '+' or '-' (the sign of the imaginary part).
    /// realPart is the string of the already-parsed real part.
    /// </summary>
    private static Token ReadComplexImaginary(TextStream reader, string realPart, SourcePos pos)
    {
        string delim = "()[]\"" + " \r\n\t";
        int c = reader.Peek();
        char sign = (char)c;
        reader.Read(); // consume the sign
        c = reader.Peek();

        // Check for +i/-i, +inf.0i/-inf.0i, +nan.0i/-nan.0i
        if (c == 'i' || c == 'I' || c == 'n' || c == 'N')
        {
            // Try to read "inf.0" or "nan.0" (max 5 chars after sign)
            StringBuilder special = new StringBuilder();
            special.Append(sign);
            int maxRead = 5; // "inf.0" or "nan.0" = 5 chars
            int count = 0;
            while (c != -1 && count < maxRead && "infINFnanNAN.0".IndexOf((char)c) >= 0)
            {
                special.Append((char)c);
                reader.Read();
                c = reader.Peek();
                count++;
            }
            string s = special.ToString().ToLowerInvariant();

            // +i or -i (pure imaginary unit)
            if (s == "+i" || s == "-i")
            {
                if (IsDelimiterOrEnd(c, delim))
                    return new Token(realPart + "|" + sign + "1", TokenType.COMPLEX, pos);
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
            }

            // +inf.0i, -inf.0i, +nan.0i, -nan.0i
            if ((s == "+inf.0" || s == "-inf.0" || s == "+nan.0" || s == "-nan.0") &&
                (c == 'i' || c == 'I'))
            {
                reader.Read(); // consume 'i'
                int next = reader.Peek();
                if (IsDelimiterOrEnd(next, delim))
                    return new Token(realPart + "|" + s, TokenType.COMPLEX, pos);
            }
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        }

        // Read imaginary digits
        StringBuilder imagDigits = new StringBuilder();
        imagDigits.Append(sign);
        while (c != -1 && c >= '0' && c <= '9')
        {
            imagDigits.Append((char)c);
            reader.Read();
            c = reader.Peek();
        }

        if (c == 'i' || c == 'I')
        {
            reader.Read();
            int next = reader.Peek();
            if (IsDelimiterOrEnd(next, delim))
                return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        }

        if (c == '/')
        {
            // Rational imaginary part
            imagDigits.Append('/');
            reader.Read();
            c = reader.Peek();
            while (c != -1 && c >= '0' && c <= '9')
            {
                imagDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            if (c == 'i' || c == 'I')
            {
                reader.Read();
                int next = reader.Peek();
                if (IsDelimiterOrEnd(next, delim))
                    return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
            }
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        }

        if (c == '.')
        {
            // Decimal imaginary part
            imagDigits.Append('.');
            reader.Read();
            c = reader.Peek();
            while (c != -1 && c >= '0' && c <= '9')
            {
                imagDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
        }

        if (c != -1 && IsExponentMarker(c))
        {
            // Exponent in imaginary part
            imagDigits.Append((char)c);
            reader.Read();
            c = reader.Peek();
            if (c == '+' || c == '-')
            {
                imagDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            while (c != -1 && c >= '0' && c <= '9')
            {
                imagDigits.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
        }

        if (c == 'i' || c == 'I')
        {
            reader.Read();
            int next = reader.Peek();
            if (IsDelimiterOrEnd(next, delim))
                return new Token(realPart + "|" + imagDigits, TokenType.COMPLEX, pos);
        }

        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
    }

    /// <summary>
    /// Reads polar form: magnitude already parsed, reader.Peek() is '@'.
    /// </summary>
    private static Token ReadPolarForm(TextStream reader, string magnitude, SourcePos pos)
    {
        reader.Read(); // consume '@'
        // Read the angle as a full number
        Token angleToken = ReadPrefixedNumber(reader, 10, false, false, pos);
        // Return as COMPLEX with polar conversion marker
        return new Token(magnitude + "@" + angleToken.value, TokenType.COMPLEX, pos);
    }
}
