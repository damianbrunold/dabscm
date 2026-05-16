package scheme;

import java.io.Writer;
import java.util.ArrayDeque;
import java.util.Collections;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.Set;
import java.io.ByteArrayInputStream;
import java.math.BigInteger;

public class Value {

    public static final Nil NIL = new Nil();
    public static final Boolean T = Boolean.TRUE;
    public static final Boolean F = Boolean.FALSE;
    public static final Byte EOF = 1;

    private static Map<String, String> symbols = new HashMap<>();

    public static String intern(String string) {
        // this ensures that symbols with identical names are
        // represented by identical string objects. thus, we
        // can compare symbols using the simple == operator.
        String result = symbols.get(string);
        if (result == null) {
            result = string;
            symbols.put(string, result);
        }
        return result;
    }

    public static Values asValues(Object value) {
        return (Values) value;
    }

    public static Long asInteger(Object value) {
        return (Long) value;
    }

    public static BigInteger asBigInteger(Object value) {
        return (BigInteger) value;
    }

    public static Double asReal(Object value) {
        return (Double) value;
    }

    public static Boolean asBoolean(Object value) {
        return (Boolean) value;
    }

    public static String asSymbol(Object value) {
        return (String) value;
    }

    public static char[] asString(Object value) {
        return (char[]) value;
    }

    public static Character asChar(Object value) {
        return (Character) value;
    }

    public static Lambda asLambda(Object value) {
        return (Lambda) value;
    }

    public static boolean isMacro(Object value) {
        return value instanceof MacroTransformer;
    }

    public static MacroTransformer asMacro(Object value) {
        return (MacroTransformer) value;
    }

    public static Primitive asPrimitive(Object value) {
        return (Primitive) value;
    }

    public static Pair asPair(Object value) {
        return (Pair) value;
    }

    public static Object[] asVector(Object value) {
        return (Object[]) value;
    }

    public static TextStream asInputPort(Object value) {
        return (TextStream) value;
    }

    public static Writer asOutputPort(Object value) {
        return (Writer) value;
    }

    public static Rational asRational(Object value) {
        return (Rational) value;
    }

    public static byte[] asBytevector(Object value) {
        return (byte[]) value;
    }

    public static BinaryInputStream asBinaryInputPort(Object value) {
        return (BinaryInputStream) value;
    }

    public static BinaryOutputStream asBinaryOutputPort(Object value) {
        return (BinaryOutputStream) value;
    }

    public static Instruction asInstruction(Object value) {
        return (Instruction) value;
    }

    @SuppressWarnings("unchecked")
    public static HashMap<String, Object> asDict(Object value) {
        return (HashMap<String, Object>) value;
    }

    public static NativeValue asNativeValue(Object value) {
        return (NativeValue) value;
    }

    public static boolean isValues(Object value) {
        return value instanceof Values;
    }

    public static boolean isFixnum(Object value) {
        return value instanceof Long;
    }

    public static boolean isBigInteger(Object value) {
        return value instanceof BigInteger;
    }

    public static boolean isInteger(Object value) {
        return value instanceof Long || value instanceof BigInteger;
    }

    public static boolean isReal(Object value) {
        return value instanceof Double;
    }

    public static boolean isBoolean(Object value) {
        return value instanceof Boolean;
    }

    public static boolean isSymbol(Object value) {
        return value instanceof String;
    }

    public static boolean isString(Object value) {
        return value instanceof char[];
    }

    public static boolean isChar(Object value) {
        return value instanceof Character;
    }

    public static boolean isVector(Object value) {
        return value instanceof Object[];
    }

    public static boolean isRecord(Object value) {
        return value instanceof Record;
    }

    public static Record asRecord(Object value) {
        return (Record) value;
    }

    public static boolean isNil(Object value) {
        return value instanceof Nil;
    }

    public static boolean isPair(Object value) {
        return value instanceof Pair;
    }

    public static boolean isLambda(Object value) {
        return value instanceof Lambda;
    }

    public static boolean isPrimitive(Object value) {
        return value instanceof Primitive;
    }

    public static boolean isNativeValue(Object value) {
        return value instanceof NativeValue;
    }

    public static boolean isRational(Object value) {
        return value instanceof Rational;
    }

    public static boolean isComplex(Object value) {
        return value instanceof Complex;
    }

    public static Complex asComplex(Object value) {
        return (Complex) value;
    }

    public static boolean isBytevector(Object value) {
        return value instanceof byte[];
    }

    public static boolean isBinaryInputPort(Object value) {
        return value instanceof BinaryInputStream;
    }

    public static boolean isBinaryOutputPort(Object value) {
        return value instanceof BinaryOutputStream;
    }

    public static boolean isInputPort(Object value) {
        return value instanceof TextStream || value instanceof BinaryInputStream;
    }

    public static boolean isOutputPort(Object value) {
        return value instanceof Writer || value instanceof BinaryOutputStream;
    }

    public static boolean isEOFObject(Object value) {
        return value instanceof Byte && value == EOF;
    }

    public static boolean isInstruction(Object value) {
        return value instanceof Instruction;
    }

    public static boolean isDict(Object value) {
        return value instanceof HashMap;
    }

    public static boolean isHashTable(Object value) {
        return value instanceof SchemeHashTable;
    }

    public static SchemeHashTable asHashTable(Object value) {
        return (SchemeHashTable) value;
    }

    public static boolean isSyntaxObject(Object value) {
        return value instanceof SyntaxObject;
    }

    public static SyntaxObject asSyntaxObject(Object value) {
        return (SyntaxObject) value;
    }

    public static boolean isAtom(Object value) {
        return isConstant(value) || isSymbol(value);
    }

    public static boolean isConstant(Object value) {
        return isFixnum(value) || isBigInteger(value) || isReal(value) || isRational(value)
            || isComplex(value) || isBoolean(value) || isString(value) || isChar(value) || isBytevector(value);
    }

    public static String printRep(Object value) {
        if (isValues(value))
            return printRepValues(asValues(value));
        if (isInteger(value))
            return value.toString();
        if (isSymbol(value))
            return printRepSymbol(asSymbol(value));
        if (isRational(value))
            return asRational(value).toString();
        if (isComplex(value))
            return asComplex(value).toString();
        if (isReal(value)) {
            return formatDouble((double) (Double) value);
        }
        if (isBoolean(value))
            return asBoolean(value) ? "#t" : "#f";
        if (isChar(value))
            return printRepChar(asChar(value));
        if (isString(value))
            return printRepString(asString(value));
        if (isNil(value))
            return "()";
        if (isPair(value))
            return printRepPair(asPair(value));
        if (isRecord(value))
            return "#<record>";
        if (isVector(value))
            return printRepVector(asVector(value));
        if (isBytevector(value))
            return printRepBytevector(asBytevector(value));
        if (isBinaryInputPort(value))
            return "#<binary-input-port>";
        if (isBinaryOutputPort(value))
            return "#<binary-output-port>";
        if (isInputPort(value))
            return "#<input-port>";
        if (isOutputPort(value))
            return "#<output-port>";
        if (isEOFObject(value))
            return "#<eof>";
        if (isDict(value))
            return "#<dict>";
        if (isHashTable(value))
            return "#<hash-table>";
        if (isInstruction(value))
            return printRepInstruction(asInstruction(value));
        return value.toString(); // TODO
    }

    public static void printRepTo(Object value, StringBuilder sb) {
        if (isValues(value)) { printRepValuesTo(asValues(value), sb); return; }
        if (isInteger(value)) { sb.append(value.toString()); return; }
        if (isSymbol(value)) { printRepSymbolTo(asSymbol(value), sb); return; }
        if (isRational(value)) { sb.append(asRational(value).toString()); return; }
        if (isComplex(value)) { sb.append(asComplex(value).toString()); return; }
        if (isReal(value)) { sb.append(formatDouble((double)(Double)value)); return; }
        if (isBoolean(value)) { sb.append(asBoolean(value) ? "#t" : "#f"); return; }
        if (isChar(value)) { printRepCharTo(asChar(value), sb); return; }
        if (isString(value)) { printRepStringTo(asString(value), sb); return; }
        if (isNil(value)) { sb.append("()"); return; }
        if (isPair(value)) { printRepPairTo(asPair(value), sb); return; }
        if (isRecord(value)) { sb.append("#<record>"); return; }
        if (isVector(value)) { printRepVectorTo(asVector(value), sb); return; }
        if (isBytevector(value)) { printRepBytevectorTo(asBytevector(value), sb); return; }
        if (isBinaryInputPort(value)) { sb.append("#<binary-input-port>"); return; }
        if (isBinaryOutputPort(value)) { sb.append("#<binary-output-port>"); return; }
        if (isInputPort(value)) { sb.append("#<input-port>"); return; }
        if (isOutputPort(value)) { sb.append("#<output-port>"); return; }
        if (isEOFObject(value)) { sb.append("#<eof>"); return; }
        if (isDict(value)) { sb.append("#<dict>"); return; }
        if (isHashTable(value)) { sb.append("#<hash-table>"); return; }
        if (isInstruction(value)) { printRepInstructionTo(asInstruction(value), sb); return; }
        if (isMacro(value)) { sb.append("#<macro>"); return; }
        sb.append(value.toString());
    }

    public static void printRepTo(Object value, Writer tw) throws java.io.IOException {
        StringBuilder sb = new StringBuilder();
        printRepTo(value, sb);
        tw.write(sb.toString());
    }

    private static void printRepValuesTo(Values values, StringBuilder sb) {
        boolean first = true;
        for (Object value : values.values) {
            if (!first) sb.append('\n');
            first = false;
            printRepTo(value, sb);
        }
    }

    private static boolean symbolNeedsDelimiters(String sym) {
        if (sym.length() == 0) return true;
        String special = "()[]{}\",'`;#| \t\n\r\\";
        for (int i = 0; i < sym.length(); i++) {
            if (special.indexOf(sym.charAt(i)) >= 0) return true;
        }
        char first = sym.charAt(0);
        if (first >= '0' && first <= '9') return true;
        if (sym.equals(".")) return true;
        if (sym.equals("+") || sym.equals("-")) return false;
        // +/- followed by anything could be numeric syntax (+inf.0, +nan.0, +i, +3, etc.)
        if ((first == '+' || first == '-') && sym.length() > 1) return true;
        return false;
    }

    private static String printRepSymbol(String sym) {
        if (!symbolNeedsDelimiters(sym)) return sym;
        StringBuilder sb = new StringBuilder();
        printRepSymbolTo(sym, sb);
        return sb.toString();
    }

    private static void printRepSymbolTo(String sym, StringBuilder sb) {
        if (!symbolNeedsDelimiters(sym)) { sb.append(sym); return; }
        sb.append('|');
        for (int i = 0; i < sym.length(); i++) {
            char c = sym.charAt(i);
            if (c == '|') { sb.append("\\|"); }
            else if (c == '\\') { sb.append("\\\\"); }
            else { sb.append(c); }
        }
        sb.append('|');
    }

    private static void printRepCharTo(char ch, StringBuilder sb) {
        switch (ch) {
            case ' ':  sb.append("#\\space"); break;
            case '\t': sb.append("#\\tab"); break;
            case '\r': sb.append("#\\return"); break;
            case '\n': sb.append("#\\newline"); break;
            default:   sb.append("#\\"); sb.append(ch); break;
        }
    }

    private static void printRepStringTo(char[] str, StringBuilder sb) {
        sb.append('"');
        for (char c : str) {
            switch (c) {
                case '"':  sb.append("\\\""); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                case '\\': sb.append("\\\\"); break;
                default:   sb.append(c); break;
            }
        }
        sb.append('"');
    }

    private static void printRepBytevectorTo(byte[] bv, StringBuilder sb) {
        sb.append("#u8(");
        for (int i = 0; i < bv.length; i++) {
            if (i > 0) sb.append(' ');
            sb.append(bv[i] & 0xFF);
        }
        sb.append(')');
    }

    private static void printRepVectorTo(Object[] elements, StringBuilder sb) {
        sb.append("#(");
        for (int i = 0; i < elements.length; i++) {
            if (i > 0) sb.append(' ');
            printRepTo(elements[i], sb);
        }
        sb.append(')');
    }

    private static void printRepPairTo(Pair pair, StringBuilder sb) {
        if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quote")) {
            sb.append('\''); printRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quasiquote")) {
            sb.append('`'); printRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote")) {
            sb.append(','); printRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote-splicing")) {
            sb.append(",@"); printRepTo(Value.asPair(pair.cdr).car, sb); return;
        }
        sb.append('(');
        Pair current = pair;
        while (true) {
            printRepTo(current.car, sb);
            if (current.cdr == Value.NIL) {
                sb.append(')');
                break;
            } else if (!Value.isPair(current.cdr)) {
                sb.append(" . "); printRepTo(current.cdr, sb); sb.append(')');
                break;
            } else {
                sb.append(' ');
            }
            current = Value.asPair(current.cdr);
        }
    }

    private static void printRepInstructionTo(Instruction instruction, StringBuilder sb) {
        sb.append("#<");
        sb.append(instruction.opcode);
        if (instruction.arg1 != null) { sb.append(' '); printRepTo(instruction.arg1, sb); }
        if (instruction.arg2 != null) { sb.append(' '); printRepTo(instruction.arg2, sb); }
        if (instruction.pos != null) { sb.append(' '); sb.append(instruction.pos); }
        sb.append('>');
    }

    public static String formatDouble(double d) {
        if (Double.isInfinite(d)) return d > 0 ? "+inf.0" : "-inf.0";
        if (Double.isNaN(d)) return "+nan.0";
        for (int p = 15; p <= 17; p++) {
            String s = String.format("%." + p + "g", d);
            if (Double.parseDouble(s) == d)
                return normalizeDouble(s);
        }
        return normalizeDouble(String.format("%.17g", d));
    }

    private static String normalizeDouble(String s) {
        int eIdx = s.indexOf('e');
        if (eIdx >= 0) {
            String mantissa = stripTrailingZeros(s.substring(0, eIdx));
            int exp = Integer.parseInt(s.substring(eIdx + 1)); // handles e+020, e-005
            return mantissa + "e" + (exp >= 0 ? "+" : "") + exp;
        }
        return stripTrailingZerosFixed(s);
    }

    private static String stripTrailingZeros(String s) {
        s = s.replaceAll("0+$", "");
        return s.endsWith(".") ? s + "0" : s;
    }

    private static String stripTrailingZerosFixed(String s) {
        if (!s.contains(".")) return s + ".0";
        s = s.replaceAll("0+$", "");
        return s.endsWith(".") ? s + "0" : s;
    }

    private static String printRepValues(Values values) {
        StringBuilder result = new StringBuilder();
        for (Object value : values.values) {
            result.append(printRep(value)).append("\n");
        }
        if (result.length() > 0)
            result.setLength(result.length() - 1);
        return result.toString();
    }

    private static String printRepChar(char ch) {
        switch (ch) {
            case ' ':
                return "#\\space";
            case '\t':
                return "#\\tab";
            case '\r':
                return "#\\return";
            case '\n':
                return "#\\newline";
            default:
                return "#\\" + ch;
        }
    }

    private static String printRepString(char[] str) {
        StringBuilder result = new StringBuilder("\"");
        result.append(new String(str)
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t"));
        result.append("\"");
        return result.toString();
    }

    private static String printRepBytevector(byte[] bv) {
        StringBuilder result = new StringBuilder("#u8(");
        for (int i = 0; i < bv.length; i++) {
            if (i > 0) result.append(' ');
            result.append(bv[i] & 0xFF);
        }
        result.append(')');
        return result.toString();
    }

    private static String printRepVector(Object[] elements) {
        StringBuilder sb = new StringBuilder("#(");
        for (int i = 0; i < elements.length; i++) {
            if (i > 0) sb.append(' ');
            printRepTo(elements[i], sb);
        }
        sb.append(')');
        return sb.toString();
    }

    private static String printRepPair(Pair pair) {
        if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quote")) {
            return "'" + printRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quasiquote")) {
            return "`" + printRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote")) {
            return "," + printRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote-splicing")) {
            return ",@" + printRep(Value.asPair(pair.cdr).car);
        }
        StringBuilder result = new StringBuilder("(");
        Pair current = pair;
        while (true) {
            result.append(printRep(current.car));
            if (current.cdr == Value.NIL) {
                result.append(")");
                break;
            } else if (!Value.isPair(current.cdr)) {
                result.append(" . ").append(printRep(current.cdr)).append(")");
                break;
            } else {
                result.append(" ");
            }
            current = Value.asPair(current.cdr);
        }
        return result.toString();
    }

    private static String printRepInstruction(Instruction instruction) {
        StringBuilder result = new StringBuilder();
        result.append("#<");
        result.append(instruction.opcode);
        if (instruction.arg1 != null)
            result.append(" ").append(printRep(instruction.arg1));
        if (instruction.arg2 != null)
            result.append(" ").append(printRep(instruction.arg2));
        result.append(">");
        return result.toString();
    }

    public static String displayRep(Object value) {
        if (isValues(value))
            return displayRepValues(asValues(value));
        if (isInteger(value) || isSymbol(value))
            return value.toString();
        if (isRational(value))
            return asRational(value).toString();
        if (isComplex(value))
            return asComplex(value).toString();
        if (isReal(value)) {
            return formatDouble((double) (Double) value);
        }
        if (isBoolean(value))
            return asBoolean(value) ? "#t" : "#f";
        if (isChar(value))
            return value.toString();
        if (isString(value))
            return new String(asString(value));
        if (isNil(value))
            return "()";
        if (isPair(value))
            return displayRepPair(asPair(value));
        if (isRecord(value))
            return "#<record>";
        if (isVector(value))
            return displayRepVector(asVector(value));
        if (isBytevector(value))
            return printRepBytevector(asBytevector(value));
        if (isBinaryInputPort(value))
            return "#<binary-input-port>";
        if (isBinaryOutputPort(value))
            return "#<binary-output-port>";
        if (isInputPort(value))
            return "#<input-port>";
        if (isOutputPort(value))
            return "#<output-port>";
        if (isEOFObject(value))
            return "#<eof>";
        if (isDict(value))
            return "#<dict>";
        if (isHashTable(value))
            return "#<hash-table>";
        if (isInstruction(value))
            return displayRepInstruction(asInstruction(value));
        return value.toString(); // TODO
    }

    public static void displayRepTo(Object value, StringBuilder sb) {
        if (isValues(value)) { displayRepValuesTo(asValues(value), sb); return; }
        if (isInteger(value) || isSymbol(value)) { sb.append(value.toString()); return; }
        if (isRational(value)) { sb.append(asRational(value).toString()); return; }
        if (isComplex(value)) { sb.append(asComplex(value).toString()); return; }
        if (isReal(value)) { sb.append(formatDouble((double)(Double)value)); return; }
        if (isBoolean(value)) { sb.append(asBoolean(value) ? "#t" : "#f"); return; }
        if (isChar(value)) { sb.append(value.toString()); return; }
        if (isString(value)) { sb.append(asString(value)); return; }
        if (isNil(value)) { sb.append("()"); return; }
        if (isPair(value)) { displayRepPairTo(asPair(value), sb); return; }
        if (isRecord(value)) { sb.append("#<record>"); return; }
        if (isVector(value)) { displayRepVectorTo(asVector(value), sb); return; }
        if (isBytevector(value)) { printRepBytevectorTo(asBytevector(value), sb); return; }
        if (isBinaryInputPort(value)) { sb.append("#<binary-input-port>"); return; }
        if (isBinaryOutputPort(value)) { sb.append("#<binary-output-port>"); return; }
        if (isInputPort(value)) { sb.append("#<input-port>"); return; }
        if (isOutputPort(value)) { sb.append("#<output-port>"); return; }
        if (isEOFObject(value)) { sb.append("#<eof>"); return; }
        if (isDict(value)) { sb.append("#<dict>"); return; }
        if (isHashTable(value)) { sb.append("#<hash-table>"); return; }
        if (isInstruction(value)) { displayRepInstructionTo(asInstruction(value), sb); return; }
        sb.append(value.toString());
    }

    public static void displayRepTo(Object value, Writer tw) throws java.io.IOException {
        StringBuilder sb = new StringBuilder();
        displayRepTo(value, sb);
        tw.write(sb.toString());
    }

    private static void displayRepValuesTo(Values values, StringBuilder sb) {
        boolean first = true;
        for (Object value : values.values) {
            if (!first) sb.append('\n');
            first = false;
            displayRepTo(value, sb);
        }
    }

    private static void displayRepVectorTo(Object[] elements, StringBuilder sb) {
        sb.append("#(");
        for (int i = 0; i < elements.length; i++) {
            if (i > 0) sb.append(' ');
            displayRepTo(elements[i], sb);
        }
        sb.append(')');
    }

    private static void displayRepPairTo(Pair pair, StringBuilder sb) {
        if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quote")) {
            sb.append('\''); displayRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quasiquote")) {
            sb.append('`'); displayRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote")) {
            sb.append(','); displayRepTo(Value.asPair(pair.cdr).car, sb); return;
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote-splicing")) {
            sb.append(",@"); displayRepTo(Value.asPair(pair.cdr).car, sb); return;
        }
        sb.append('(');
        Pair current = pair;
        while (true) {
            displayRepTo(current.car, sb);
            if (current.cdr == Value.NIL) {
                sb.append(')');
                break;
            } else if (!Value.isPair(current.cdr)) {
                sb.append(" . "); displayRepTo(current.cdr, sb); sb.append(')');
                break;
            } else {
                sb.append(' ');
            }
            current = Value.asPair(current.cdr);
        }
    }

    private static void displayRepInstructionTo(Instruction instruction, StringBuilder sb) {
        sb.append(instruction.opcode);
        if (instruction.arg1 != null) { sb.append(' '); printRepTo(instruction.arg1, sb); }
        if (instruction.arg2 != null) { sb.append(' '); printRepTo(instruction.arg2, sb); }
        if (instruction.pos != null) { sb.append(' '); sb.append(instruction.pos); }
    }

    private static String displayRepVector(Object[] elements) {
        StringBuilder sb = new StringBuilder("#(");
        for (int i = 0; i < elements.length; i++) {
            if (i > 0) sb.append(' ');
            displayRepTo(elements[i], sb);
        }
        sb.append(')');
        return sb.toString();
    }

    private static String displayRepPair(Pair pair) {
        if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quote")) {
            return "'" + displayRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("quasiquote")) {
            return "`" + displayRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote")) {
            return "," + displayRep(Value.asPair(pair.cdr).car);
        } else if (Value.isSymbol(pair.car) && Value.asSymbol(pair.car).equals("unquote-splicing")) {
            return ",@" + displayRep(Value.asPair(pair.cdr).car);
        }
        StringBuilder result = new StringBuilder("(");
        Pair current = pair;
        while (true) {
            result.append(displayRep(current.car));
            if (current.cdr == Value.NIL) {
                result.append(")");
                break;
            } else if (!Value.isPair(current.cdr)) {
                result.append(" . ").append(displayRep(current.cdr)).append(")");
                break;
            } else {
                result.append(" ");
            }
            current = Value.asPair(current.cdr);
        }
        return result.toString();
    }

    private static String displayRepValues(Values values) {
        StringBuilder result = new StringBuilder();
        for (Object value : values.values) {
            result.append(displayRep(value)).append("\n");
        }
        if (result.length() > 0)
            result.setLength(result.length() - 1);
        return result.toString();
    }

    private static String displayRepInstruction(Instruction instruction) {
        StringBuilder result = new StringBuilder();
        result.append(instruction.opcode);
        if (instruction.arg1 != null)
            result.append(" ").append(printRep(instruction.arg1));
        if (instruction.arg2 != null)
            result.append(" ").append(printRep(instruction.arg2));
        if (instruction.pos != null)
            result.append(" ").append(instruction.pos);
        return result.toString();
    }

    // --- Cycle/sharing detection ---

    public static String printRepCyclic(Object value) { return printRepWithLabels(value, false); }
    public static String printRepShared(Object value) { return printRepWithLabels(value, true); }

    private static boolean isCompoundForLabeling(Object value) {
        return isPair(value) || isVector(value);
    }

    private static Set<Object> identitySet() {
        return Collections.newSetFromMap(new IdentityHashMap<>());
    }

    private static void countRefs(Object value, IdentityHashMap<Object, int[]> refCount) {
        ArrayDeque<Object> stack = new ArrayDeque<>();
        stack.push(value);
        while (!stack.isEmpty()) {
            Object v = stack.pop();
            if (!isCompoundForLabeling(v)) continue;
            int[] count = refCount.get(v);
            if (count != null) { count[0]++; continue; }
            refCount.put(v, new int[]{1});
            if (isPair(v)) {
                Pair p = asPair(v);
                if (p.cdr != null) stack.push(p.cdr);
                if (p.car != null) stack.push(p.car);
            } else if (isVector(v)) {
                Object[] vec = asVector(v);
                for (int i = vec.length - 1; i >= 0; i--) stack.push(vec[i]);
            }
        }
    }

    private static final Object EXIT_MARKER = new Object();

    private static void findCycles(Object value,
            Set<Object> onStack, Set<Object> done, Set<Object> cyclic) {
        ArrayDeque<Object> stack = new ArrayDeque<>();
        stack.push(value);
        while (!stack.isEmpty()) {
            Object v = stack.pop();
            if (v == EXIT_MARKER) {
                Object node = stack.pop();
                onStack.remove(node);
                done.add(node);
                continue;
            }
            if (!isCompoundForLabeling(v) || done.contains(v)) continue;
            if (onStack.contains(v)) { cyclic.add(v); continue; }
            onStack.add(v);
            stack.push(v);
            stack.push(EXIT_MARKER);
            if (isPair(v)) {
                Pair p = asPair(v);
                if (p.cdr != null) stack.push(p.cdr);
                if (p.car != null) stack.push(p.car);
            } else if (isVector(v)) {
                Object[] vec = asVector(v);
                for (int i = vec.length - 1; i >= 0; i--) stack.push(vec[i]);
            }
        }
    }

    private static String printRepWithLabels(Object value, boolean allShared) {
        Set<Object> needsLabel;
        if (allShared) {
            IdentityHashMap<Object, int[]> refCount = new IdentityHashMap<>();
            countRefs(value, refCount);
            needsLabel = identitySet();
            for (Map.Entry<Object, int[]> e : refCount.entrySet()) {
                if (e.getValue()[0] > 1) needsLabel.add(e.getKey());
            }
        } else {
            needsLabel = identitySet();
            findCycles(value, identitySet(), identitySet(), needsLabel);
        }
        if (needsLabel.isEmpty()) return printRep(value);
        IdentityHashMap<Object, Integer> assigned = new IdentityHashMap<>();
        int[] nextLabel = {0};
        StringBuilder sb = new StringBuilder();
        printLabeled(value, needsLabel, assigned, nextLabel, sb);
        return sb.toString();
    }

    private static void printLabeled(Object value,
            Set<Object> needsLabel, IdentityHashMap<Object, Integer> assigned,
            int[] nextLabel, StringBuilder sb) {
        if (!isCompoundForLabeling(value)) { sb.append(printRep(value)); return; }
        if (needsLabel.contains(value)) {
            Integer existing = assigned.get(value);
            if (existing != null) { sb.append('#').append(existing).append('#'); return; }
            int label = nextLabel[0]++;
            assigned.put(value, label);
            sb.append('#').append(label).append('=');
        }
        if (isNil(value)) sb.append("()");
        else if (isPair(value)) printLabeledPair(asPair(value), needsLabel, assigned, nextLabel, sb);
        else if (isVector(value)) printLabeledVector(asVector(value), needsLabel, assigned, nextLabel, sb);
    }

    private static void printLabeledPair(Pair pair,
            Set<Object> needsLabel, IdentityHashMap<Object, Integer> assigned,
            int[] nextLabel, StringBuilder sb) {
        sb.append('(');
        Pair current = pair;
        boolean first = true;
        while (true) {
            if (!first) sb.append(' ');
            first = false;
            printLabeled(current.car, needsLabel, assigned, nextLabel, sb);
            if (current.cdr == NIL) {
                sb.append(')'); break;
            } else if (!isPair(current.cdr)) {
                sb.append(" . ");
                printLabeled(current.cdr, needsLabel, assigned, nextLabel, sb);
                sb.append(')'); break;
            } else if (needsLabel.contains(current.cdr)) {
                sb.append(" . ");
                printLabeled(current.cdr, needsLabel, assigned, nextLabel, sb);
                sb.append(')'); break;
            } else {
                current = asPair(current.cdr);
            }
        }
    }

    private static void printLabeledVector(Object[] vec,
            Set<Object> needsLabel, IdentityHashMap<Object, Integer> assigned,
            int[] nextLabel, StringBuilder sb) {
        sb.append("#(");
        for (int i = 0; i < vec.length; i++) {
            if (i > 0) sb.append(' ');
            printLabeled(vec[i], needsLabel, assigned, nextLabel, sb);
        }
        sb.append(')');
    }

    public static void printRepCyclicTo(Object value, Writer tw) throws java.io.IOException {
        StringBuilder sb = new StringBuilder();
        printRepWithLabelsTo(value, false, sb);
        tw.write(sb.toString());
    }

    public static void printRepSharedTo(Object value, Writer tw) throws java.io.IOException {
        StringBuilder sb = new StringBuilder();
        printRepWithLabelsTo(value, true, sb);
        tw.write(sb.toString());
    }

    private static void printRepWithLabelsTo(Object value, boolean allShared, StringBuilder sb) {
        Set<Object> needsLabel;
        if (allShared) {
            IdentityHashMap<Object, int[]> refCount = new IdentityHashMap<>();
            countRefs(value, refCount);
            needsLabel = identitySet();
            for (Map.Entry<Object, int[]> e : refCount.entrySet()) {
                if (e.getValue()[0] > 1) needsLabel.add(e.getKey());
            }
        } else {
            needsLabel = identitySet();
            findCycles(value, identitySet(), identitySet(), needsLabel);
        }
        if (needsLabel.isEmpty()) { printRepTo(value, sb); return; }
        IdentityHashMap<Object, Integer> assigned = new IdentityHashMap<>();
        int[] nextLabel = {0};
        printLabeled(value, needsLabel, assigned, nextLabel, sb);
    }

}
