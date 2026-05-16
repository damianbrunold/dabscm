using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text;

namespace scheme;

public class Value
{
    public static Nil NIL = new();
    public static bool T = true;
    public static bool F = false;
    public static byte EOF = 1;

    private static Dictionary<string, string> symbols = new();

    public static string Intern(string str)
    {
        if (!symbols.ContainsKey(str))
        {
            symbols[str] = str;
        }
        return symbols[str];
    }

    public static Values AsValues(object value)
    {
        return (Values)value;
    }

    public static NativeValue AsNativeValue(object value)
    {
        return (NativeValue)value;
    }

    public static long AsInteger(object value)
    {
        return (long)value;
    }

    public static BigInteger AsBigInteger(object value)
    {
        return (BigInteger)value;
    }

    public static double AsReal(object value)
    {
        return (double)value;
    }

    public static bool AsBoolean(object value)
    {
        return (bool)value;
    }

    public static string AsSymbol(object value)
    {
        return (string)value;
    }

    public static char[] AsString(object value)
    {
        return (char[])value;
    }

    public static char AsChar(object value)
    {
        return (char)value;
    }

    public static Lambda AsLambda(object value)
    {
        return (Lambda)value;
    }

    public static bool IsMacro(object value)
    {
        return value is MacroTransformer;
    }

    public static MacroTransformer AsMacro(object value)
    {
        return (MacroTransformer)value;
    }

    public static Primitive AsPrimitive(object value)
    {
        return (Primitive)value;
    }

    public static Pair AsPair(object value)
    {
        return (Pair)value;
    }

    public static object[] AsVector(object value)
    {
        return (object[])value;
    }

    public static TextStream AsInputPort(object value)
    {
        return (TextStream)value;
    }

    public static TextWriter AsOutputPort(object value)
    {
        return (TextWriter)value;
    }

    public static Rational AsRational(object value)
    {
        return (Rational)value;
    }

    public static byte[] AsBytevector(object value)
    {
        return (byte[])value;
    }

    public static BinaryInputStream AsBinaryInputPort(object value)
    {
        return (BinaryInputStream)value;
    }

    public static BinaryOutputStream AsBinaryOutputPort(object value)
    {
        return (BinaryOutputStream)value;
    }

    public static Instruction AsInstruction(object value)
    {
        return (Instruction)value;
    }

    public static Dictionary<string, object> AsDict(object value)
    {
        return (Dictionary<string, object>)value;
    }

    public static bool IsValues(object value)
    {
        return value is Values;
    }

    public static bool IsNativeValue(object value)
    {
        return value is NativeValue;
    }

    public static bool IsFixnum(object value)
    {
        return value is long;
    }

    public static bool IsBigInteger(object value)
    {
        return value is BigInteger;
    }

    public static bool IsInteger(object value)
    {
        return value is long || value is BigInteger;
    }

    public static bool IsReal(object value)
    {
        return value is double;
    }

    public static bool IsBoolean(object value)
    {
        return value is bool;
    }

    public static bool IsSymbol(object value)
    {
        return value is string;
    }

    public static bool IsString(object value)
    {
        return value is char[];
    }

    public static bool IsChar(object value)
    {
        return value is char;
    }

    public static bool IsVector(object value)
    {
        return value is object[];
    }

    public static bool IsRecord(object value)
    {
        return value is Record;
    }

    public static Record AsRecord(object value)
    {
        return (Record)value;
    }

    public static bool IsNil(object value)
    {
        return value is Nil;
    }

    public static bool IsPair(object value)
    {
        return value is Pair;
    }

    public static bool IsLambda(object value)
    {
        return value is Lambda;
    }

    public static bool IsPrimitive(object value)
    {
        return value is Primitive;
    }

    public static bool IsRational(object value)
    {
        return value is Rational;
    }

    public static bool IsComplex(object value)
    {
        return value is Complex;
    }

    public static Complex AsComplex(object value)
    {
        return (Complex)value;
    }

    public static bool IsBytevector(object value)
    {
        return value is byte[];
    }

    public static bool IsBinaryInputPort(object value)
    {
        return value is BinaryInputStream;
    }

    public static bool IsBinaryOutputPort(object value)
    {
        return value is BinaryOutputStream;
    }

    public static bool IsInputPort(object value)
    {
        return value is TextStream || value is BinaryInputStream;
    }

    public static bool IsOutputPort(object value)
    {
        return value is TextWriter || value is BinaryOutputStream;
    }

    public static bool IsEOFObject(object value)
    {
        return value is byte && ((byte)value) == EOF;
    }

    public static bool IsInstruction(object value)
    {
        return value is Instruction;
    }

    public static bool IsDict(object value)
    {
        return value is Dictionary<string, object>;
    }

    public static bool IsHashTable(object value)
    {
        return value is SchemeHashTable;
    }

    public static SchemeHashTable AsHashTable(object value)
    {
        return (SchemeHashTable)value;
    }

    public static bool IsSyntaxObject(object value)
    {
        return value is SyntaxObject;
    }

    public static SyntaxObject AsSyntaxObject(object value)
    {
        return (SyntaxObject)value;
    }

    public static bool IsAtom(object value)
    {
        return IsConstant(value) || IsSymbol(value);
    }

    public static bool IsConstant(object value)
    {
        return IsFixnum(value) || IsBigInteger(value) || IsReal(value) || IsRational(value)
            || IsComplex(value) || IsBoolean(value) || IsString(value)
            || IsChar(value) || IsBytevector(value);
    }

    public static string PrintRep(object value)
    {
        if (IsValues(value)) return PrintRepValues(AsValues(value));
        if (IsInteger(value)) return value?.ToString() ?? "?";
        if (IsSymbol(value)) return PrintRepSymbol(AsSymbol(value));
        if (IsRational(value)) return AsRational(value).ToString();
        if (IsComplex(value)) return AsComplex(value).ToString();
        if (IsReal(value)) return FormatDouble(AsReal(value));
        if (IsBoolean(value)) return AsBoolean(value) ? "#t" : "#f";
        if (IsChar(value)) return PrintRepChar(AsChar(value));
        if (IsString(value)) return PrintRepString(AsString(value));
        if (IsNil(value)) return "()";
        if (IsPair(value)) return PrintRepPair(AsPair(value));
        if (IsRecord(value)) return "#<record>";
        if (IsVector(value)) return PrintRepVector(AsVector(value));
        if (IsBytevector(value)) return PrintRepBytevector(AsBytevector(value));
        if (IsBinaryInputPort(value)) return "#<binary-input-port>";
        if (IsBinaryOutputPort(value)) return "#<binary-output-port>";
        if (IsInputPort(value)) return "#<input-port>";
        if (IsOutputPort(value)) return "#<output-port>";
        if (IsEOFObject(value)) return "#<eof>";
        if (IsDict(value)) return "#<dict>";
        if (IsHashTable(value)) return "#<hash-table>";
        if (IsInstruction(value)) return PrintRepInstruction(AsInstruction(value));
        if (value is SyntaxObject stx) return stx.ToString();
        return value?.ToString() ?? "?";
    }

    public static void PrintRepTo(object value, StringBuilder sb)
    {
        if (IsValues(value)) { PrintRepValuesTo(AsValues(value), sb); return; }
        if (IsInteger(value)) { sb.Append(value?.ToString() ?? "?"); return; }
        if (IsSymbol(value)) { PrintRepSymbolTo(AsSymbol(value), sb); return; }
        if (IsRational(value)) { sb.Append(AsRational(value).ToString()); return; }
        if (IsComplex(value)) { sb.Append(AsComplex(value).ToString()); return; }
        if (IsReal(value)) { sb.Append(FormatDouble(AsReal(value))); return; }
        if (IsBoolean(value)) { sb.Append(AsBoolean(value) ? "#t" : "#f"); return; }
        if (IsChar(value)) { PrintRepCharTo(AsChar(value), sb); return; }
        if (IsString(value)) { PrintRepStringTo(AsString(value), sb); return; }
        if (IsNil(value)) { sb.Append("()"); return; }
        if (IsPair(value)) { PrintRepPairTo(AsPair(value), sb); return; }
        if (IsRecord(value)) { sb.Append("#<record>"); return; }
        if (IsVector(value)) { PrintRepVectorTo(AsVector(value), sb); return; }
        if (IsBytevector(value)) { PrintRepBytevectorTo(AsBytevector(value), sb); return; }
        if (IsBinaryInputPort(value)) { sb.Append("#<binary-input-port>"); return; }
        if (IsBinaryOutputPort(value)) { sb.Append("#<binary-output-port>"); return; }
        if (IsInputPort(value)) { sb.Append("#<input-port>"); return; }
        if (IsOutputPort(value)) { sb.Append("#<output-port>"); return; }
        if (IsEOFObject(value)) { sb.Append("#<eof>"); return; }
        if (IsDict(value)) { sb.Append("#<dict>"); return; }
        if (IsHashTable(value)) { sb.Append("#<hash-table>"); return; }
        if (IsInstruction(value)) { PrintRepInstructionTo(AsInstruction(value), sb); return; }
        if (IsMacro(value)) { sb.Append("#<macro>"); return; }
        sb.Append(value?.ToString() ?? "?");
    }

    public static void PrintRepTo(object value, TextWriter tw)
    {
        var sb = new StringBuilder();
        PrintRepTo(value, sb);
        tw.Write(sb.ToString());
    }

    private static void PrintRepValuesTo(Values values, StringBuilder sb)
    {
        bool first = true;
        foreach (object value in values.values)
        {
            if (!first) sb.Append('\n');
            first = false;
            PrintRepTo(value, sb);
        }
    }

    private static bool SymbolNeedsDelimiters(string sym)
    {
        if (sym.Length == 0) return true;
        const string special = "()[]{}\",'`;#| \t\n\r\\";
        foreach (char c in sym)
        {
            if (special.IndexOf(c) >= 0) return true;
        }
        // Check if it would be read as something other than a symbol
        char first = sym[0];
        if (first >= '0' && first <= '9') return true;
        if (sym == ".") return true;
        if (sym == "+" || sym == "-") return false; // bare + or - are symbols
        // +/- followed by anything could be numeric syntax (+inf.0, +nan.0, +i, +3, etc.)
        if ((first == '+' || first == '-') && sym.Length > 1) return true;
        return false;
    }

    private static string PrintRepSymbol(string sym)
    {
        if (!SymbolNeedsDelimiters(sym)) return sym;
        var sb = new StringBuilder();
        PrintRepSymbolTo(sym, sb);
        return sb.ToString();
    }

    private static void PrintRepSymbolTo(string sym, StringBuilder sb)
    {
        if (!SymbolNeedsDelimiters(sym)) { sb.Append(sym); return; }
        sb.Append('|');
        foreach (char c in sym)
        {
            if (c == '|') { sb.Append("\\|"); }
            else if (c == '\\') { sb.Append("\\\\"); }
            else { sb.Append(c); }
        }
        sb.Append('|');
    }

    private static void PrintRepCharTo(char ch, StringBuilder sb)
    {
        switch (ch)
        {
            case ' ':  sb.Append("#\\space"); break;
            case '\t': sb.Append("#\\tab"); break;
            case '\r': sb.Append("#\\return"); break;
            case '\n': sb.Append("#\\newline"); break;
            default:   sb.Append("#\\"); sb.Append(ch); break;
        }
    }

    private static void PrintRepStringTo(char[] str, StringBuilder sb)
    {
        sb.Append('"');
        foreach (char c in str)
        {
            switch (c)
            {
                case '"':  sb.Append("\\\""); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                case '\\': sb.Append("\\\\"); break;
                default:   sb.Append(c); break;
            }
        }
        sb.Append('"');
    }

    private static void PrintRepBytevectorTo(byte[] bv, StringBuilder sb)
    {
        sb.Append("#u8(");
        for (int i = 0; i < bv.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            sb.Append(bv[i] & 0xFF);
        }
        sb.Append(')');
    }

    private static void PrintRepVectorTo(object[] elements, StringBuilder sb)
    {
        sb.Append("#(");
        for (int i = 0; i < elements.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            PrintRepTo(elements[i], sb);
        }
        sb.Append(')');
    }

    private static void PrintRepPairTo(Pair pair, StringBuilder sb)
    {
        if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quote"))
        {
            sb.Append('\''); PrintRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quasiquote"))
        {
            sb.Append('`'); PrintRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote"))
        {
            sb.Append(','); PrintRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote-splicing"))
        {
            sb.Append(",@"); PrintRepTo(Value.AsPair(pair.cdr).car!, sb); return;
        }
        sb.Append('(');
        Pair current = pair;
        while (true)
        {
            PrintRepTo(current.car!, sb);
            if (current.cdr == Value.NIL)
            {
                sb.Append(')');
                break;
            }
            else if (!Value.IsPair(current.cdr))
            {
                sb.Append(" . "); PrintRepTo(current.cdr, sb); sb.Append(')');
                break;
            }
            else
            {
                sb.Append(' ');
            }
            current = Value.AsPair(current.cdr);
        }
    }

    private static void PrintRepInstructionTo(Instruction instruction, StringBuilder sb)
    {
        sb.Append("#<");
        sb.Append(instruction.opcode);
        if (instruction.arg1 != null) { sb.Append(' '); PrintRepTo(instruction.arg1, sb); }
        if (instruction.arg2 != null) { sb.Append(' '); PrintRepTo(instruction.arg2, sb); }
        if (instruction.pos != null) { sb.Append(' '); sb.Append(instruction.pos); }
        sb.Append('>');
    }

    public static string FormatDouble(double d)
    {
        if (double.IsPositiveInfinity(d)) return "+inf.0";
        if (double.IsNegativeInfinity(d)) return "-inf.0";
        if (double.IsNaN(d)) return "+nan.0";
        for (int p = 15; p <= 17; p++)
        {
            string s = d.ToString("G" + p, CultureInfo.InvariantCulture);
            if (double.Parse(s, CultureInfo.InvariantCulture) == d)
                return NormalizeDouble(s);
        }
        return NormalizeDouble(d.ToString("G17", CultureInfo.InvariantCulture));
    }

    private static string NormalizeDouble(string s)
    {
        int eIdx = s.IndexOf('E');
        if (eIdx >= 0)
        {
            string mantissa = s.Substring(0, eIdx);
            if (!mantissa.Contains('.')) mantissa += ".0";
            int exp = int.Parse(s.Substring(eIdx + 1)); // handles E+020, E-005
            return mantissa + "e" + (exp >= 0 ? "+" : "") + exp;
        }
        if (!s.Contains('.')) s += ".0";
        return s;
    }

    private static string PrintRepValues(Values values)
    {
        StringBuilder result = new StringBuilder();
        foreach (object value in values.values)
        {
            result.Append(PrintRep(value)).Append("\n");
        }
        if (result.Length > 0) result.Length--;
        return result.ToString();
    }

    private static string PrintRepChar(char ch)
    {
        switch (ch)
        {
            case ' ': return "#\\space";
            case '\t': return "#\\tab";
            case '\r': return "#\\return";
            case '\n': return "#\\newline";
            default: return "#\\" + ch;
        }
    }

    private static string PrintRepString(char[] str)
    {
        StringBuilder result = new StringBuilder("\"");
        result.Append(
            new String(str)
            .Replace("\"", "\\\"")
            .Replace("\n", "\\n")
            .Replace("\r", "\\r")
            .Replace("\t", "\\t")
        );
        result.Append("\"");
        return result.ToString();
    }

    private static string PrintRepBytevector(byte[] bv)
    {
        StringBuilder result = new StringBuilder("#u8(");
        for (int i = 0; i < bv.Length; i++)
        {
            if (i > 0) result.Append(' ');
            result.Append(bv[i] & 0xFF);
        }
        result.Append(')');
        return result.ToString();
    }

    private static string PrintRepVector(object[] elements)
    {
        var sb = new StringBuilder("#(");
        for (int i = 0; i < elements.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            PrintRepTo(elements[i], sb);
        }
        sb.Append(')');
        return sb.ToString();
    }

    private static string PrintRepPair(Pair pair)
    {
        if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quote"))
        {
            return "'" + PrintRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quasiquote"))
        {
            return "`" + PrintRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote"))
        {
            return "," + PrintRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote-splicing"))
        {
            return ",@" + PrintRep(Value.AsPair(pair.cdr).car!);
        }
        StringBuilder result = new StringBuilder("(");
        Pair current = pair;
        while (true)
        {
            result.Append(PrintRep(current.car!));
            if (current.cdr == Value.NIL)
            {
                result.Append(")");
                break;
            }
            else if (!Value.IsPair(current.cdr))
            {
                result.Append(" . ").Append(PrintRep(current.cdr)).Append(")");
                break;
            }
            else
            {
                result.Append(" ");
            }
            current = Value.AsPair(current.cdr);
        }
        return result.ToString();
    }

    private static string PrintRepInstruction(Instruction instruction)
    {
        StringBuilder result = new StringBuilder();
        result.Append("#<");
        result.Append(instruction.opcode);
        if (instruction.arg1 != null) result.Append(" ").Append(PrintRep(instruction.arg1));
        if (instruction.arg2 != null) result.Append(" ").Append(PrintRep(instruction.arg2));
        if (instruction.pos != null) result.Append(" ").Append(instruction.pos);
        result.Append(">");
        return result.ToString();
    }

    public static string DisplayRep(object value)
    {
        if (IsValues(value)) return DisplayRepValues(AsValues(value));
        if (IsInteger(value) || IsSymbol(value)) return value?.ToString() ?? "?";
        if (IsRational(value)) return AsRational(value).ToString();
        if (IsComplex(value)) return AsComplex(value).ToString();
        if (IsReal(value)) return FormatDouble(AsReal(value));
        if (IsBoolean(value)) return AsBoolean(value) ? "#t" : "#f";
        if (IsChar(value)) return value?.ToString() ?? "?";
        if (IsString(value)) return new String(AsString(value));
        if (IsNil(value)) return "()";
        if (IsPair(value)) return DisplayRepPair(AsPair(value));
        if (IsRecord(value)) return "#<record>";
        if (IsVector(value)) return DisplayRepVector(AsVector(value));
        if (IsBytevector(value)) return PrintRepBytevector(AsBytevector(value));
        if (IsBinaryInputPort(value)) return "#<binary-input-port>";
        if (IsBinaryOutputPort(value)) return "#<binary-output-port>";
        if (IsInputPort(value)) return "#<input-port>";
        if (IsOutputPort(value)) return "#<output-port>";
        if (IsEOFObject(value)) return "#<eof>";
        if (IsDict(value)) return "#<dict>";
        if (IsHashTable(value)) return "#<hash-table>";
        if (IsInstruction(value)) return DisplayRepInstruction(AsInstruction(value));
        return value?.ToString() ?? "?";
    }

    public static void DisplayRepTo(object value, StringBuilder sb)
    {
        if (IsValues(value)) { DisplayRepValuesTo(AsValues(value), sb); return; }
        if (IsInteger(value) || IsSymbol(value)) { sb.Append(value?.ToString() ?? "?"); return; }
        if (IsRational(value)) { sb.Append(AsRational(value).ToString()); return; }
        if (IsComplex(value)) { sb.Append(AsComplex(value).ToString()); return; }
        if (IsReal(value)) { sb.Append(FormatDouble(AsReal(value))); return; }
        if (IsBoolean(value)) { sb.Append(AsBoolean(value) ? "#t" : "#f"); return; }
        if (IsChar(value)) { sb.Append(value?.ToString() ?? "?"); return; }
        if (IsString(value)) { sb.Append(AsString(value)); return; }
        if (IsNil(value)) { sb.Append("()"); return; }
        if (IsPair(value)) { DisplayRepPairTo(AsPair(value), sb); return; }
        if (IsRecord(value)) { sb.Append("#<record>"); return; }
        if (IsVector(value)) { DisplayRepVectorTo(AsVector(value), sb); return; }
        if (IsBytevector(value)) { PrintRepBytevectorTo(AsBytevector(value), sb); return; }
        if (IsBinaryInputPort(value)) { sb.Append("#<binary-input-port>"); return; }
        if (IsBinaryOutputPort(value)) { sb.Append("#<binary-output-port>"); return; }
        if (IsInputPort(value)) { sb.Append("#<input-port>"); return; }
        if (IsOutputPort(value)) { sb.Append("#<output-port>"); return; }
        if (IsEOFObject(value)) { sb.Append("#<eof>"); return; }
        if (IsDict(value)) { sb.Append("#<dict>"); return; }
        if (IsHashTable(value)) { sb.Append("#<hash-table>"); return; }
        if (IsInstruction(value)) { DisplayRepInstructionTo(AsInstruction(value), sb); return; }
        sb.Append(value?.ToString() ?? "?");
    }

    public static void DisplayRepTo(object value, TextWriter tw)
    {
        var sb = new StringBuilder();
        DisplayRepTo(value, sb);
        tw.Write(sb.ToString());
    }

    private static void DisplayRepValuesTo(Values values, StringBuilder sb)
    {
        bool first = true;
        foreach (object value in values.values)
        {
            if (!first) sb.Append('\n');
            first = false;
            DisplayRepTo(value, sb);
        }
    }

    private static void DisplayRepVectorTo(object[] elements, StringBuilder sb)
    {
        sb.Append("#(");
        for (int i = 0; i < elements.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            DisplayRepTo(elements[i], sb);
        }
        sb.Append(')');
    }

    private static void DisplayRepPairTo(Pair pair, StringBuilder sb)
    {
        if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quote"))
        {
            sb.Append('\''); DisplayRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quasiquote"))
        {
            sb.Append('`'); DisplayRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote"))
        {
            sb.Append(','); DisplayRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote-splicing"))
        {
            sb.Append(",@"); DisplayRepTo(Value.AsPair(pair.cdr).car, sb); return;
        }
        sb.Append('(');
        Pair current = pair;
        while (true)
        {
            DisplayRepTo(current.car!, sb);
            if (current.cdr == Value.NIL)
            {
                sb.Append(')');
                break;
            }
            else if (!Value.IsPair(current.cdr))
            {
                sb.Append(" . "); DisplayRepTo(current.cdr, sb); sb.Append(')');
                break;
            }
            else
            {
                sb.Append(' ');
            }
            current = Value.AsPair(current.cdr);
        }
    }

    private static void DisplayRepInstructionTo(Instruction instruction, StringBuilder sb)
    {
        sb.Append(instruction.opcode);
        if (instruction.arg1 != null) { sb.Append(' '); PrintRepTo(instruction.arg1, sb); }
        if (instruction.arg2 != null) { sb.Append(' '); PrintRepTo(instruction.arg2, sb); }
        if (instruction.pos != null) { sb.Append(' '); sb.Append(instruction.pos); }
    }

    private static string DisplayRepVector(object[] elements)
    {
        var sb = new StringBuilder("#(");
        for (int i = 0; i < elements.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            DisplayRepTo(elements[i], sb);
        }
        sb.Append(')');
        return sb.ToString();
    }

    private static string DisplayRepPair(Pair pair)
    {
        if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quote"))
        {
            return "'" + DisplayRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("quasiquote"))
        {
            return "`" + DisplayRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote"))
        {
            return "," + DisplayRep(Value.AsPair(pair.cdr).car);
        }
        else if (Value.IsSymbol(pair.car!) && Value.AsSymbol(pair.car!).Equals("unquote-splicing"))
        {
            return ",@" + DisplayRep(Value.AsPair(pair.cdr).car);
        }
        StringBuilder result = new StringBuilder("(");
        Pair current = pair;
        while (true)
        {
            result.Append(DisplayRep(current.car!));
            if (current.cdr == Value.NIL)
            {
                result.Append(")");
                break;
            }
            else if (!Value.IsPair(current.cdr))
            {
                result.Append(" . ").Append(DisplayRep(current.cdr)).Append(")");
                break;
            }
            else
            {
                result.Append(" ");
            }
            current = Value.AsPair(current.cdr);
        }
        return result.ToString();
    }

    private static string DisplayRepValues(Values values)
    {
        StringBuilder result = new StringBuilder();
        foreach (Object value in values.values)
        {
            result.Append(DisplayRep(value)).Append("\n");
        }
        if (result.Length > 0) result.Length--;
        return result.ToString();
    }

    private static string DisplayRepInstruction(Instruction instruction)
    {
        StringBuilder result = new StringBuilder();
        result.Append(instruction.opcode);
        if (instruction.arg1 != null) result.Append(" ").Append(PrintRep(instruction.arg1));
        if (instruction.arg2 != null) result.Append(" ").Append(PrintRep(instruction.arg2));
        if (instruction.pos != null) result.Append(" ").Append(instruction.pos);
        return result.ToString();
    }

    // --- Cycle/sharing detection ---

    public static string PrintRepCyclic(object value) => PrintRepWithLabels(value, false);
    public static string PrintRepShared(object value) => PrintRepWithLabels(value, true);

    private static bool IsCompoundForLabeling(object value) =>
        IsPair(value) || IsVector(value);

    private static void CountRefs(object value, Dictionary<object, int> refCount)
    {
        var stack = new Stack<object>();
        stack.Push(value);
        while (stack.Count > 0)
        {
            var v = stack.Pop();
            if (!IsCompoundForLabeling(v)) continue;
            if (refCount.TryGetValue(v, out int count)) { refCount[v] = count + 1; continue; }
            refCount[v] = 1;
            if (IsPair(v)) {
                var p = AsPair(v);
                if (p.cdr != null) stack.Push(p.cdr);
                if (p.car != null) stack.Push(p.car);
            } else if (IsVector(v)) {
                var vec = AsVector(v);
                for (int i = vec.Length - 1; i >= 0; i--) stack.Push(vec[i]);
            }
        }
    }

    private static void FindCycles(object value,
        HashSet<object> onStack, HashSet<object> done, HashSet<object> cyclic)
    {
        var stack = new Stack<(bool isExit, object value)>();
        stack.Push((false, value));
        while (stack.Count > 0)
        {
            var (isExit, v) = stack.Pop();
            if (isExit) { onStack.Remove(v); done.Add(v); continue; }
            if (!IsCompoundForLabeling(v) || done.Contains(v)) continue;
            if (onStack.Contains(v)) { cyclic.Add(v); continue; }
            onStack.Add(v);
            stack.Push((true, v));
            if (IsPair(v)) {
                var p = AsPair(v);
                if (p.cdr != null) stack.Push((false, p.cdr));
                if (p.car != null) stack.Push((false, p.car));
            } else if (IsVector(v)) {
                var vec = AsVector(v);
                for (int i = vec.Length - 1; i >= 0; i--) stack.Push((false, vec[i]));
            }
        }
    }

    private static string PrintRepWithLabels(object value, bool allShared)
    {
        HashSet<object> needsLabel;
        if (allShared) {
            var refCount = new Dictionary<object, int>(ReferenceEqualityComparer.Instance);
            CountRefs(value, refCount);
            needsLabel = new HashSet<object>(
                refCount.Where(kv => kv.Value > 1).Select(kv => kv.Key),
                ReferenceEqualityComparer.Instance);
        } else {
            needsLabel = new HashSet<object>(ReferenceEqualityComparer.Instance);
            FindCycles(value,
                new HashSet<object>(ReferenceEqualityComparer.Instance),
                new HashSet<object>(ReferenceEqualityComparer.Instance),
                needsLabel);
        }
        if (needsLabel.Count == 0) return PrintRep(value);
        var assigned = new Dictionary<object, int>(ReferenceEqualityComparer.Instance);
        int nextLabel = 0;
        var sb = new StringBuilder();
        PrintLabeled(value, needsLabel, assigned, ref nextLabel, sb);
        return sb.ToString();
    }

    private static void PrintLabeled(object value,
        HashSet<object> needsLabel, Dictionary<object, int> assigned,
        ref int nextLabel, StringBuilder sb)
    {
        if (!IsCompoundForLabeling(value)) { sb.Append(PrintRep(value)); return; }
        if (needsLabel.Contains(value)) {
            if (assigned.TryGetValue(value, out int existingLabel)) {
                sb.Append('#').Append(existingLabel).Append('#'); return;
            }
            int label = nextLabel++;
            assigned[value] = label;
            sb.Append('#').Append(label).Append('=');
        }
        if (IsNil(value)) sb.Append("()");
        else if (IsPair(value)) PrintLabeledPair(AsPair(value), needsLabel, assigned, ref nextLabel, sb);
        else if (IsVector(value)) PrintLabeledVector(AsVector(value), needsLabel, assigned, ref nextLabel, sb);
    }

    private static void PrintLabeledPair(Pair pair,
        HashSet<object> needsLabel, Dictionary<object, int> assigned,
        ref int nextLabel, StringBuilder sb)
    {
        sb.Append('(');
        Pair current = pair;
        bool first = true;
        while (true) {
            if (!first) sb.Append(' ');
            first = false;
            PrintLabeled(current.car!, needsLabel, assigned, ref nextLabel, sb);
            if (current.cdr == NIL) {
                sb.Append(')'); break;
            } else if (!IsPair(current.cdr)) {
                sb.Append(" . ");
                PrintLabeled(current.cdr!, needsLabel, assigned, ref nextLabel, sb);
                sb.Append(')'); break;
            } else if (needsLabel.Contains(current.cdr)) {
                sb.Append(" . ");
                PrintLabeled(current.cdr, needsLabel, assigned, ref nextLabel, sb);
                sb.Append(')'); break;
            } else {
                current = AsPair(current.cdr);
            }
        }
    }

    private static void PrintLabeledVector(object[] vec,
        HashSet<object> needsLabel, Dictionary<object, int> assigned,
        ref int nextLabel, StringBuilder sb)
    {
        sb.Append("#(");
        for (int i = 0; i < vec.Length; i++) {
            if (i > 0) sb.Append(' ');
            PrintLabeled(vec[i], needsLabel, assigned, ref nextLabel, sb);
        }
        sb.Append(')');
    }

    public static void PrintRepCyclicTo(object value, TextWriter tw)
    {
        var sb = new StringBuilder();
        PrintRepWithLabelsTo(value, false, sb);
        tw.Write(sb.ToString());
    }

    public static void PrintRepSharedTo(object value, TextWriter tw)
    {
        var sb = new StringBuilder();
        PrintRepWithLabelsTo(value, true, sb);
        tw.Write(sb.ToString());
    }

    private static void PrintRepWithLabelsTo(object value, bool allShared, StringBuilder sb)
    {
        HashSet<object> needsLabel;
        if (allShared) {
            var refCount = new Dictionary<object, int>(ReferenceEqualityComparer.Instance);
            CountRefs(value, refCount);
            needsLabel = new HashSet<object>(
                refCount.Where(kv => kv.Value > 1).Select(kv => kv.Key),
                ReferenceEqualityComparer.Instance);
        } else {
            needsLabel = new HashSet<object>(ReferenceEqualityComparer.Instance);
            FindCycles(value,
                new HashSet<object>(ReferenceEqualityComparer.Instance),
                new HashSet<object>(ReferenceEqualityComparer.Instance),
                needsLabel);
        }
        if (needsLabel.Count == 0) { PrintRepTo(value, sb); return; }
        var assigned = new Dictionary<object, int>(ReferenceEqualityComparer.Instance);
        int nextLabel = 0;
        PrintLabeled(value, needsLabel, assigned, ref nextLabel, sb);
    }
}
