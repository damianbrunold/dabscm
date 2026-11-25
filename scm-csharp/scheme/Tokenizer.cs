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

    private static bool IsWhitespace(char ch) =>
        ch == ' ' || ch == '\r' || ch == '\n' || ch == '\t';

    // R7RS delimiters (whitespace, ( ) " ; |) and [ ]
    private static bool IsDelim(char ch) =>
        ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '"' || ch == ';' || ch == '|' || IsWhitespace(ch);

    // a real with an exponent; "1e+" (a sign without digits) is malformed
    private static Token ExponentToken(string text, SourcePos pos)
    {
        char last = text[text.Length - 1];
        if (last == '+' || last == '-')
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed exponent", Array.Empty<object>()));
        return new Token(text, TokenType.REAL, pos);
    }

    private static bool HasDigit(StringBuilder token)
    {
        for (int i = 0; i < token.Length; i++)
            if (token[i] >= '0' && token[i] <= '9') return true;
        return false;
    }

    public static Token? ReadToken(TextStream reader)
    {
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
                    else if (IsWhitespace(ch))
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
                    else if ((ch == '/' || IsExponentMarker(ch)) && !HasDigit(token))
                    {
                        // "-/1", "-d00": a sign alone is no numerator or mantissa
                        token.Append(ch);
                        state = 3; // symbol
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
                    else if (IsDelim(ch))
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
                        if (IsDelimiterOrEnd(next))
                        {
                            string imagStr = token.ToString();
                            if (imagStr == "+" || imagStr == "-")
                                imagStr += "1";
                            return ComplexToken("0", imagStr, pos);
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
                        if (IsDelimiterOrEnd(next))
                        {
                            return ComplexToken("0", token.ToString(), pos);
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
                    else if (IsDelim(ch))
                    {
                        putback = true;
                        return RationalToken(token.ToString(), pos);
                    }
                    else
                    {
                        // not a number: a symbol (as 1x)
                        token.Append(ch);
                        state = 3;
                    }
                    break;

                case 11: // real
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                    }
                    else if (IsExponentMarker(ch) && HasDigit(token))
                    {
                        token.Append(ch);
                        state = 14; // exponent
                    }
                    else
                    {
                        string rtok = token.ToString();
                        if (rtok.Equals("+.") || rtok.Equals("-."))
                        {
                            // +.a, -.@ (R7RS peculiar identifiers), +. : symbols
                            if (IsDelim(ch))
                            {
                                putback = true;
                                return new Token(Maybefold(reader, rtok), TokenType.SYMBOL, pos);
                            }
                            token.Append(ch);
                            state = 3;
                        }
                        else if (ch == '+' || ch == '-')
                        {
                            return ReadComplexImaginary(reader, rtok, pos);
                        }
                        else if ((ch == 'i' || ch == 'I') && (rtok[0] == '+' || rtok[0] == '-'))
                        {
                            reader.Read();
                            int next = reader.Peek();
                            if (IsDelimiterOrEnd(next))
                                return ComplexToken("0", rtok, pos);
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
                        else if (IsDelim(ch))
                        {
                            putback = true;
                            return new Token(rtok, TokenType.REAL, pos);
                        }
                        else
                        {
                            // not a number: a symbol (as 1x)
                            token.Append(ch);
                            state = 3;
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
                    else if (!char.IsDigit(token[token.Length - 1]))
                    {
                        // 1e+ without exponent digits
                        throw new SchemeError(pos, new ReadErrorObject("tokenizer: malformed exponent", Array.Empty<object>()));
                    }
                    else if (ch == '+' || ch == '-')
                    {
                        return ReadComplexImaginary(reader, token.ToString(), pos);
                    }
                    else if (ch == '@')
                    {
                        return ReadPolarForm(reader, token.ToString(), pos);
                    }
                    else if (IsDelim(ch))
                    {
                        putback = true;
                        return ExponentToken(token.ToString(), pos);
                    }
                    else
                    {
                        // not a number: a symbol (as 1x)
                        token.Append(ch);
                        state = 3;
                    }
                    break;

                case 12: // dot or real
                    if ('0' <= ch && ch <= '9')
                    {
                        token.Append(ch);
                        state = 11;
                    }
                    else if (IsDelim(ch))
                    {
                        putback = true;
                        return new Token(".", TokenType.DOT, pos);
                    }
                    else
                    {
                        // "..", "...", ".a", ".+": identifiers (R7RS peculiar
                        // identifiers; others as 1x is read)
                        token.Append(ch);
                        state = 3;
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
                    if (IsDelim(ch))
                    {
                        putback = true;
                        return SymbolOrInfNan(Maybefold(reader, token.ToString()), pos);
                    }
                    else if ((ch == '+' || ch == '-') && token.Length >= 5)
                    {
                        var symLower = token.ToString().ToLowerInvariant();
                        if (symLower == "+inf.0" || symLower == "-inf.0" || symLower == "+nan.0"
                            || symLower == "-nan.0")
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
                        while (dc != -1 && !IsDelim((char)dc))
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
                    if (IsDelim(ch))
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
                    if (IsDelim(ch))
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
                    if (IsDelim(ch))
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
        if ((state == 0 || state == 7) && (token == null || token.Length == 0)) return null;
        if (state == 1)
        {
            if (token.ToString().Equals("+") || token.ToString().Equals("-"))
            {
                return new Token(Maybefold(reader, token.ToString()), TokenType.SYMBOL, pos);
            }
            return new Token(token.ToString(), TokenType.INTEGER, pos);
        }
        else if (state == 4)
        {
            return new Token(",", TokenType.COMMA, pos);
        }
        else if (state == 12)
        {
            return new Token(".", TokenType.DOT, pos);
        }
        else if (state == 11 || state == 15)
        {
            string rtok = token.ToString();
            if (rtok.Equals("+.") || rtok.Equals("-."))
                return new Token(Maybefold(reader, rtok), TokenType.SYMBOL, pos);
            return state == 15 ? ExponentToken(rtok, pos) : new Token(rtok, TokenType.REAL, pos);
        }
        else if (state == 14)
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("tokenizer: malformed exponent", Array.Empty<object>()));
        }
        else if (state == 13)
        {
            return RationalToken(token.ToString(), pos);
        }
        else if (state == 2)
        {
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: String not closed", Array.Empty<object>()));
        }
        else if (state == 3)
        {
            return SymbolOrInfNan(Maybefold(reader, token.ToString()), pos);
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

    /// <summary>The exact value of a decimal (with an optional exponent): #e1.2 is 6/5.</summary>
    public static object ExactDecimal(string numStr)
    {
        // digits and scale, as Java's BigDecimal unscaledValue/scale
        int i = 0;
        bool neg = false;
        if (i < numStr.Length && (numStr[i] == '+' || numStr[i] == '-')) { neg = numStr[i] == '-'; i++; }
        var digits = new StringBuilder();
        int scale = 0;
        while (i < numStr.Length && char.IsAsciiDigit(numStr[i])) digits.Append(numStr[i++]);
        if (i < numStr.Length && numStr[i] == '.')
        {
            i++;
            while (i < numStr.Length && char.IsAsciiDigit(numStr[i])) { digits.Append(numStr[i++]); scale++; }
        }
        if (i < numStr.Length && IsExponentMarker(numStr[i]))
        {
            i++;
            bool expNeg = false;
            if (i < numStr.Length && (numStr[i] == '+' || numStr[i] == '-')) { expNeg = numStr[i] == '-'; i++; }
            int expStart = i;
            while (i < numStr.Length && char.IsAsciiDigit(numStr[i])) i++;
            if (i == expStart) throw new FormatException("malformed exponent: " + numStr);
            int exp = int.Parse(numStr.AsSpan(expStart, i - expStart), System.Globalization.CultureInfo.InvariantCulture);
            scale += expNeg ? exp : -exp;
        }
        if (i != numStr.Length || digits.Length == 0) throw new FormatException("malformed decimal: " + numStr);
        var unscaled = System.Numerics.BigInteger.Parse(digits.ToString(), System.Globalization.CultureInfo.InvariantCulture);
        if (neg) unscaled = -unscaled;
        if (scale <= 0)
            return IntegerMath.Normalize(unscaled * System.Numerics.BigInteger.Pow(10, -scale));
        return Rational.Create(IntegerMath.Normalize(unscaled),
                               IntegerMath.Normalize(System.Numerics.BigInteger.Pow(10, scale)));
    }

    private static Token ExactDecimalToken(string numStr, SourcePos pos)
    {
        object v = ExactDecimal(numStr);
        return new Token(v.ToString()!, Value.IsInteger(v) ? TokenType.INTEGER : TokenType.RATIONAL, pos);
    }

    // The imaginary part "+<digits>i", "-<digits>/<digits>i", "+i" or "-i"
    // in radix 2, 8 or 16; the sign is next.
    private static Token ReadRadixImaginary(TextStream reader, int radix, string realPart, SourcePos pos)
    {
        string imag;
        int sign = reader.Peek();
        reader.Read();
        int c = reader.Peek();
        if (c == 'i' || c == 'I')
            imag = (char)sign + "1";
        else if (IsDigitInRadix((char)c, radix))
        {
            Token t = ReadPrefixedNumber(reader, radix, false, false, pos);
            imag = (sign == '-' ? "-" : "+") + t.value;
            c = reader.Peek();
        }
        else
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        if (c != 'i' && c != 'I')
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        reader.Read();
        if (!IsDelimiterOrEnd(reader.Peek()))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        return ComplexToken(realPart, imag, pos);
    }

    private static Token ReadPrefixedNumberOrComplex(TextStream reader, int radix, bool forceExact, bool forceInexact, SourcePos pos)
    {
        Token token = ReadPrefixedNumber(reader, radix, forceExact, forceInexact, pos);
        int c = reader.Peek();
        Token? complex = null;
        if ((c == '+' || c == '-') && radix != 10)
        {
            // the imaginary part in the radix too (#b101-11i is 5-3i)
            complex = ReadRadixImaginary(reader, radix, token.value, pos);
        }
        else if (c == '+' || c == '-')
        {
            // Complex continuation: read imaginary part
            complex = ReadComplexImaginary(reader, token.value, pos);
        }
        else if (c == '@')
        {
            complex = ReadPolarForm(reader, token.value, pos);
        }
        if (complex != null)
        {
            // the exactness prefix applies to both parts
            if (forceExact || forceInexact)
                return new Token((forceExact ? "#e" : "#i") + complex.value, TokenType.COMPLEX, pos);
            return complex;
        }
        // a number ends at a delimiter (#b1.1, #x1.8 are not numbers)
        if (!IsDelimiterOrEnd(c))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid number", Array.Empty<object>()));
        return token;
    }

    private static Token ReadPrefixedNumber(TextStream reader, int radix, bool forceExact, bool forceInexact, SourcePos pos)
    {
        // Read optional sign
        int sign = 1;
        int c = reader.Peek();
        bool signed = c == '+' || c == '-';
        if (c == '+') { reader.Read(); sign = 1; c = reader.Peek(); }
        else if (c == '-') { reader.Read(); sign = -1; c = reader.Peek(); }

        // +i and -i, in any radix (R7RS <complex R>: + i | - i)
        bool readI = false;
        if (signed && (c == 'i' || c == 'I'))
        {
            reader.Read();
            c = reader.Peek();
            if (IsDelimiterOrEnd(c))
                return new Token((forceExact ? "#e" : forceInexact ? "#i" : "") + "0|" + (sign < 0 ? "-1" : "1"), TokenType.COMPLEX, pos);
            if (radix != 10)
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected digits in number", Array.Empty<object>()));
            readI = true;
        }

        // Check for +inf.0, -inf.0, +nan.0 (after sign; "#inan.0" is no number)
        if (radix == 10 && (readI || c == 'i' || c == 'I' || c == 'n' || c == 'N'))
        {
            if (!signed) throw InvalidNumber(pos);
            StringBuilder special = new StringBuilder();
            special.Append(sign < 0 ? '-' : '+');
            if (readI) special.Append('i');
            while (c != -1 && "infINFnanNAN.0".IndexOf((char)c) >= 0)
            {
                special.Append((char)c);
                reader.Read();
                c = reader.Peek();
            }
            string s = special.ToString().ToLowerInvariant();
            if ((s == "+inf.0" || s == "-inf.0") && forceExact)
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: #e applied to non-finite number", Array.Empty<object>()));
            if (s == "+inf.0") return new Token("+inf.0", TokenType.REAL, pos);
            if (s == "-inf.0") return new Token("-inf.0", TokenType.REAL, pos);
            if (s == "+nan.0" || s == "-nan.0")
            {
                if (forceExact)
                    throw new SchemeError(pos, new ReadErrorObject("tokenizer: #e applied to non-finite number", Array.Empty<object>()));
                return new Token("+nan.0", TokenType.REAL, pos);
            }
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
                object q = Rational.Create(intVal, denomVal);
                double dv = q is Rational qr ? qr.ToDouble() : IntegerMath.ToDouble(q);
                return DoubleToken(dv, pos);
            }
            object result = Rational.Create(intVal, denomVal);
            if (Value.IsInteger(result)) return new Token(result.ToString()!, TokenType.INTEGER, pos);
            Rational r = (Rational)result;
            return new Token(r.ToString(), TokenType.RATIONAL, pos);
        }

        // Real: check for '.' (decimal/hex only)
        if (c == '.' && radix == 10)
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
            // "#i." and "#e-." are no numbers
            if (digits.Length == 0 && fracDigits.Length == 0) throw InvalidNumber(pos);
            string numStr = (sign < 0 ? "-" : "") + digits + "." + (fracDigits.Length > 0 ? fracDigits.ToString() : "0");
            // Check for exponent
            if (IsExponentMarker(c) && radix == 10) // any marker (#e1f2 as 1f2)
            {
                numStr += 'e';
                reader.Read(); c = reader.Peek();
                if (c == '+' || c == '-') { numStr += (char)c; reader.Read(); c = reader.Peek(); }
                StringBuilder expDigits = new StringBuilder();
                while (c != -1 && c >= '0' && c <= '9') { expDigits.Append((char)c); reader.Read(); c = reader.Peek(); }
                if (expDigits.Length == 0) throw InvalidNumber(pos);
                numStr += expDigits;
            }
            if (forceExact) return ExactDecimalToken(numStr, pos);
            double dval = double.Parse(numStr, System.Globalization.CultureInfo.InvariantCulture);
            return DoubleToken(dval, pos);
        }

        // Exponent on integer (decimal only)
        if (IsExponentMarker(c) && radix == 10) // any marker (#e1f2 as 1f2)
        {
            string numStr = (sign < 0 ? "-" : "") + digits + 'e';
            reader.Read(); c = reader.Peek();
            if (c == '+' || c == '-') { numStr += (char)c; reader.Read(); c = reader.Peek(); }
            StringBuilder expDigits = new StringBuilder();
            while (c != -1 && c >= '0' && c <= '9') { expDigits.Append((char)c); reader.Read(); c = reader.Peek(); }
            if (expDigits.Length == 0) throw InvalidNumber(pos);
            numStr += expDigits;
            if (forceExact) return ExactDecimalToken(numStr, pos);
            double dval = double.Parse(numStr, System.Globalization.CultureInfo.InvariantCulture);
            return DoubleToken(dval, pos);
        }

        // Plain integer
        if (forceInexact)
        {
            double dv = IntegerMath.ToDouble(intVal);
            return DoubleToken(dv, pos);
        }
        return new Token(intVal.ToString()!, TokenType.INTEGER, pos);
    }

    // a REAL token of a double; the infinities and NaN as Scheme writes
    // them (G17 would give "Infinity")
    private static Token DoubleToken(double d, SourcePos pos)
    {
        string text = double.IsNaN(d) ? "+nan.0" : double.IsPositiveInfinity(d) ? "+inf.0"
            : double.IsNegativeInfinity(d) ? "-inf.0"
            : d.ToString("G17", System.Globalization.CultureInfo.InvariantCulture);
        return new Token(text, TokenType.REAL, pos);
    }

    private static SchemeError InvalidNumber(SourcePos pos)
        => new SchemeError(pos, new ReadErrorObject("tokenizer: invalid number", Array.Empty<object>()));

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

    private static bool IsDelimiterOrEnd(int c)
    {
        return c == -1 || c == ';' || IsDelim((char)c);
    }

    /// <summary>
    /// After reading the real part of a complex number, reads the imaginary part.
    /// reader.Peek() should be '+' or '-' (the sign of the imaginary part).
    /// realPart is the string of the already-parsed real part.
    /// </summary>
    // A decimal real as the parts of a complex number are written: an
    // integer, a rational, a decimal with an optional exponent, or a signed
    // inf.0 or nan.0. The tokenizer, not a .NET parse, rejects anything else.
    private static readonly Regex RealText = new Regex(
        @"^([+-]?([0-9]+(/[0-9]+)?|([0-9]+\.?[0-9]*|\.[0-9]+)([esfdlESFDL][+-]?[0-9]+)?)|[+-](inf|nan)\.0)$",
        RegexOptions.CultureInvariant);

    private static bool IsRealText(string s) => RealText.IsMatch(s);

    private static Token ComplexToken(string realPart, string imag, SourcePos pos)
    {
        if (!IsRealText(realPart) || !IsRealText(imag))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        return new Token(realPart + "|" + imag, TokenType.COMPLEX, pos);
    }

    private static Token ReadComplexImaginary(TextStream reader, string realPart, SourcePos pos)
    {
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
                if (IsDelimiterOrEnd(c))
                    return ComplexToken(realPart, sign + "1", pos);
                throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
            }

            // +inf.0i, -inf.0i, +nan.0i, -nan.0i
            if ((s == "+inf.0" || s == "-inf.0" || s == "+nan.0" || s == "-nan.0") &&
                (c == 'i' || c == 'I'))
            {
                reader.Read(); // consume 'i'
                int next = reader.Peek();
                if (IsDelimiterOrEnd(next))
                    return ComplexToken(realPart, s, pos);
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
            if (IsDelimiterOrEnd(next))
                return ComplexToken(realPart, imagDigits.ToString(), pos);
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
                if (IsDelimiterOrEnd(next))
                    return ComplexToken(realPart, imagDigits.ToString(), pos);
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
            if (IsDelimiterOrEnd(next))
                return ComplexToken(realPart, imagDigits.ToString(), pos);
        }

        throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
    }

    /// <summary>
    /// Reads polar form: magnitude already parsed, reader.Peek() is '@'.
    /// </summary>
    // n/d: an error without d or with d zero
    private static Token RationalToken(string text, SourcePos pos)
    {
        int slash = text.IndexOf('/');
        string d = text.Substring(slash + 1);
        if (d.Length == 0)
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: expected denominator after /", Array.Empty<object>()));
        if (d.All(ch => ch == '0'))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: division by zero in rational literal", Array.Empty<object>()));
        return new Token(text, TokenType.RATIONAL, pos);
    }

    // a symbol token, or one of the numbers that read like symbols: +inf.0,
    // -inf.0, +nan.0, -nan.0 and the pure imaginary +inf.0i ... -nan.0i
    private static Token SymbolOrInfNan(string sym, SourcePos pos)
    {
        string l = sym.ToLowerInvariant();
        if (l == "+inf.0" || l == "-inf.0" || l == "+nan.0")
            return new Token(l, TokenType.REAL, pos);
        if (l == "-nan.0")
            return new Token("+nan.0", TokenType.REAL, pos);
        if (l == "+inf.0i" || l == "-inf.0i" || l == "+nan.0i" || l == "-nan.0i")
            return new Token("0|" + l.Substring(0, 6), TokenType.COMPLEX, pos);
        return new Token(sym, TokenType.SYMBOL, pos);
    }

    private static Token ReadPolarForm(TextStream reader, string magnitude, SourcePos pos)
    {
        reader.Read(); // consume '@'
        // Read the angle as a full number
        Token angleToken = ReadPrefixedNumber(reader, 10, false, false, pos);
        // "9@1.50a" is no number (not 9@1.50 then a)
        if (!IsDelimiterOrEnd(reader.Peek()))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        // Return as COMPLEX with polar conversion marker
        if (!IsRealText(magnitude))
            throw new SchemeError(pos, new ReadErrorObject("tokenizer: invalid complex number", Array.Empty<object>()));
        return new Token(magnitude + "@" + angleToken.value, TokenType.COMPLEX, pos);
    }
}
