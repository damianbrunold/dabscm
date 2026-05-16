using System.Globalization;

namespace scheme;

public class PrimitiveRead : Primitive
{
    private Modules modules;

    public PrimitiveRead(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "read";
    }

    public override string Info()
    {
        return
            "Syntax: (read)\n" +
            "Library: (scheme read)\n" +
            "Description: Reads an external representation of a Scheme object from the given port and returns the object. If no more objects are available, an end-of-file object is returned. If port is omitted, the current input port is used.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"(a b c)\"))\n" +
            "  (read p) => (a b c)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        try
        {
            if (arguments.Length == 0)
            {
                var scmcore = modules.GetModuleRequired(pos, "scm core");
                var port = Value.AsInputPort(scmcore.Resolve(pos, "*input-port*"));
                return Read(port);
            }
            else
            {
                var port = Value.AsInputPort(arguments[0]);
                return Read(port);
            }
        }
        catch (SchemeError e)
        {
            if (e.errorObject != null) throw; // preserve ReadErrorObject/FileErrorObject
            throw new SchemeError(pos, new ReadErrorObject("read: " + e.Message, Array.Empty<object>()));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, new ReadErrorObject("read: io failure: " + e.Message, Array.Empty<object>()));
        }
    }

    public object Read(TextStream reader)
    {
        return ReadDatum(ReadToken(reader), reader, new Dictionary<int, object>());
    }

    public object Read(Token? token, TextStream reader)
    {
        return ReadDatum(token, reader, new Dictionary<int, object>());
    }

    private object ReadDatum(Token? token, TextStream reader, Dictionary<int, object> labels)
    {
        if (token == null) return Value.EOF;
        if (token.type == TokenType.DATUMCOMMENT)
        {
            ReadDatum(ReadToken(reader), reader, labels); // discard next datum
            return ReadDatum(ReadToken(reader), reader, labels);
        }
        if (token.type == TokenType.CLOSEPAR)
        {
            throw new SchemeError(token.pos, new ReadErrorObject("read: unexpected )", Array.Empty<object>()));
        }
        if (token.type == TokenType.INTEGER)
        {
            if (long.TryParse(token.value, CultureInfo.InvariantCulture, out long lv)) return lv;
            return System.Numerics.BigInteger.Parse(token.value, CultureInfo.InvariantCulture);
        }
        else if (token.type == TokenType.RATIONAL)
        {
            int slash = token.value.IndexOf('/');
            string ns = token.value.Substring(0, slash), ds = token.value.Substring(slash + 1);
            object n = long.TryParse(ns, CultureInfo.InvariantCulture, out long nl) ? nl : (object)System.Numerics.BigInteger.Parse(ns, CultureInfo.InvariantCulture);
            object d = long.TryParse(ds, CultureInfo.InvariantCulture, out long dl) ? dl : (object)System.Numerics.BigInteger.Parse(ds, CultureInfo.InvariantCulture);
            return Rational.Create(n, d);
        }
        else if (token.type == TokenType.REAL)
        {
            if (token.value == "+inf.0") return double.PositiveInfinity;
            if (token.value == "-inf.0") return double.NegativeInfinity;
            if (token.value == "+nan.0") return double.NaN;
            // Normalize R7RS exponent markers (s, f, d, l) to 'e' for double.Parse
            var realStr = token.value;
            foreach (char em in "sfdlSFDL")
                realStr = realStr.Replace(em, 'e');
            return double.Parse(realStr, CultureInfo.InvariantCulture);
        }
        else if (token.type == TokenType.COMPLEX)
        {
            return ParseComplexToken(token.value, token.pos);
        }
        else if (token.type == TokenType.STRING)
        {
            return token.value.ToCharArray();
        }
        else if (token.type == TokenType.CHARACTER)
        {
            return token.value[0];
        }
        else if (token.type == TokenType.TRUE)
        {
            return Value.T;
        }
        else if (token.type == TokenType.FALSE)
        {
            return Value.F;
        }
        else if (token.type == TokenType.SYMBOL)
        {
            return Value.Intern(token.value);
        }
        else if (token.type == TokenType.QUOTE)
        {
            return Pair.List(Value.Intern("quote"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.BACKQUOTE)
        {
            return Pair.List(Value.Intern("quasiquote"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.COMMA)
        {
            return Pair.List(Value.Intern("unquote"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.COMMAAT)
        {
            return Pair.List(Value.Intern("unquote-splicing"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.SYNTAX)
        {
            return Pair.List(Value.Intern("syntax"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.QUASISYNTAX)
        {
            return Pair.List(Value.Intern("quasisyntax"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.UNSYNTAX)
        {
            return Pair.List(Value.Intern("unsyntax"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.UNSYNTAXSPLICING)
        {
            return Pair.List(Value.Intern("unsyntax-splicing"), ReadDatum(ReadToken(reader), reader, labels));
        }
        else if (token.type == TokenType.OPENPAR)
        {
            token = ReadToken(reader);
            if (token == null)
            {
                throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
            }
            if (token.type == TokenType.CLOSEPAR)
            {
                return Value.NIL;
            }
            else
            {
                Pair result = new Pair(ReadDatum(token, reader, labels), Value.NIL, token.pos);
                Pair current = result;
                token = ReadToken(reader);
                while (token != null && token.type != TokenType.CLOSEPAR && token.type != TokenType.DOT)
                {
                    object value = ReadDatum(token, reader, labels);
                    Pair next = new Pair(value, Value.NIL);
                    current.cdr = next;
                    current = next;
                    token = ReadToken(reader);
                }
                if (token != null && token.type == TokenType.DOT)
                {
                    current.cdr = ReadDatum(ReadToken(reader), reader, labels);
                    token = ReadToken(reader);
                    while (token != null && token.type == TokenType.DATUMCOMMENT)
                    {
                        ReadDatum(ReadToken(reader), reader, labels); // discard commented datum
                        token = ReadToken(reader);
                    }
                }
                if (token == null)
                    throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
                if (token.type != TokenType.CLOSEPAR)
                {
                    throw new SchemeError(reader.Pos(), new ReadErrorObject("read: expected )", Array.Empty<object>()));
                }
                return result;
            }
        }
        else if (token.type == TokenType.SHARPOPENPAR)
        {
            var elements = new List<object>();
            token = ReadToken(reader);
            while (token != null && token.type != TokenType.CLOSEPAR)
            {
                elements.Add(ReadDatum(token, reader, labels));
                token = ReadToken(reader);
            }
            if (token == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
            return elements.ToArray();
        }
        else if (token.type == TokenType.BYTEVECTOROPENPAR)
        {
            List<byte> bv = new();
            token = ReadToken(reader);
            while (token != null && token.type != TokenType.CLOSEPAR)
            {
                object elem = ReadDatum(token, reader, labels);
                if (!Value.IsInteger(elem))
                    throw new SchemeError(token.pos, new ReadErrorObject("read: bytevector elements must be exact integers", new object[] { elem }));
                long val = IntegerMath.ToLong(elem);
                if (val < 0 || val > 255)
                    throw new SchemeError(token.pos, new ReadErrorObject("read: bytevector element out of range", new object[] { val }));
                bv.Add((byte)val);
                token = ReadToken(reader);
            }
            if (token == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
            return bv.ToArray();
        }
        else if (token.type == TokenType.LABELDEFINITION)
        {
            int labelN = int.Parse(token.value, CultureInfo.InvariantCulture);
            Token? next = ReadToken(reader);
            if (next == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
            if (next.type == TokenType.OPENPAR)
            {
                Token? firstTok = ReadToken(reader);
                if (firstTok == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
                if (firstTok.type == TokenType.CLOSEPAR)
                {
                    labels[labelN] = Value.NIL;
                    return Value.NIL;
                }
                Pair result = new Pair(null!, Value.NIL, next.pos);
                labels[labelN] = result;
                result.car = ReadDatum(firstTok, reader, labels);
                Pair current = result;
                Token? t = ReadToken(reader);
                while (t != null && t.type != TokenType.CLOSEPAR && t.type != TokenType.DOT)
                {
                    Pair nxt = new Pair(ReadDatum(t, reader, labels), Value.NIL);
                    current.cdr = nxt;
                    current = nxt;
                    t = ReadToken(reader);
                }
                if (t == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
                if (t.type == TokenType.DOT)
                {
                    current.cdr = ReadDatum(ReadToken(reader), reader, labels);
                    ReadToken(reader); // consume closing )
                }
                return result;
            }
            else if (next.type == TokenType.SHARPOPENPAR)
            {
                var elements = new List<object>();
                Token? t = ReadToken(reader);
                while (t != null && t.type != TokenType.CLOSEPAR)
                {
                    elements.Add(ReadDatum(t, reader, labels));
                    t = ReadToken(reader);
                }
                if (t == null) throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected end of file", Array.Empty<object>()));
                object[] vec = elements.ToArray();
                labels[labelN] = vec;
                return vec;
            }
            else
            {
                object val = ReadDatum(next, reader, labels);
                labels[labelN] = val;
                return val;
            }
        }
        else if (token.type == TokenType.LABELREFERENCE)
        {
            int labelN = int.Parse(token.value, CultureInfo.InvariantCulture);
            if (!labels.TryGetValue(labelN, out object? obj))
                throw new SchemeError(token.pos, new ReadErrorObject("read: undefined datum label", new object[] { (long)labelN }));
            return obj!;
        }
        else
        {
            throw new SchemeError(reader.Pos(), new ReadErrorObject("read: unexpected token", new object[] { token!.ToString()!.ToCharArray() }));
        }
    }

    public static Token? ReadToken(TextStream reader)
    {
	return Tokenizer.ReadToken(reader);
    }

    private static object ParseComplexToken(string value, SourcePos pos)
    {
        // Polar form: "magnitude@angle"
        int atIdx = value.IndexOf('@');
        if (atIdx >= 0)
        {
            string magStr = value.Substring(0, atIdx);
            string angStr = value.Substring(atIdx + 1);
            double mag = ParseRealStr(magStr);
            double ang = ParseRealStr(angStr);
            return Complex.Create(mag * Math.Cos(ang), mag * Math.Sin(ang));
        }

        // Rectangular form: "realPart|imagPart"
        int pipe = value.IndexOf('|');
        if (pipe < 0)
            throw new SchemeError(pos, "read: invalid complex token: ~s", value);
        string realStr = value.Substring(0, pipe);
        string imagStr = value.Substring(pipe + 1);
        object realPart = ParseNumberStr(realStr);
        object imagPart = ParseNumberStr(imagStr);
        return Complex.Create(realPart, imagPart);
    }

    private static object ParseNumberStr(string s)
    {
        if (s == "+inf.0") return double.PositiveInfinity;
        if (s == "-inf.0") return double.NegativeInfinity;
        if (s == "+nan.0" || s == "-nan.0") return double.NaN;
        if (s.Contains('/'))
        {
            int slash = s.IndexOf('/');
            string ns = s.Substring(0, slash), ds = s.Substring(slash + 1);
            object n = long.TryParse(ns, CultureInfo.InvariantCulture, out long nl) ? nl : (object)System.Numerics.BigInteger.Parse(ns, CultureInfo.InvariantCulture);
            object d = long.TryParse(ds, CultureInfo.InvariantCulture, out long dl) ? dl : (object)System.Numerics.BigInteger.Parse(ds, CultureInfo.InvariantCulture);
            return Rational.Create(n, d);
        }
        if (s.Contains('.') || s.Contains('e') || s.Contains('E') ||
            s.Contains('s') || s.Contains('S') || s.Contains('f') || s.Contains('F') ||
            s.Contains('d') || s.Contains('D') || s.Contains('l') || s.Contains('L'))
        {
            var rs = s;
            foreach (char em in "sfdlSFDL")
                rs = rs.Replace(em, 'e');
            return double.Parse(rs, CultureInfo.InvariantCulture);
        }
        if (long.TryParse(s, CultureInfo.InvariantCulture, out long lv)) return lv;
        return System.Numerics.BigInteger.Parse(s, CultureInfo.InvariantCulture);
    }

    private static double ParseRealStr(string s)
    {
        if (s == "+inf.0") return double.PositiveInfinity;
        if (s == "-inf.0") return double.NegativeInfinity;
        if (s == "+nan.0" || s == "-nan.0") return double.NaN;
        var rs = s;
        foreach (char em in "sfdlSFDL")
            rs = rs.Replace(em, 'e');
        return double.Parse(rs, CultureInfo.InvariantCulture);
    }
}
