package scheme;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import scheme.primitives.*;

public class Compiler {

    private Modules modules;
    private BindingTable bindingTable;

    private static final String[] CXR_NAMES = {
        "caar", "cadr", "cadar", "cdar", "cddr",
        "caaar", "caadr", "caddr", "cdaar", "cdadr", "cddar", "cdddr",
        "caaaar", "caaadr", "caadar", "caaddr", "cadaar", "cadadr", "caddar", "cadddr",
        "cdaaar", "cdaadr", "cdadar", "cdaddr", "cddaar", "cddadr", "cdddar", "cddddr"
    };

    // Intrinsic opcodes: bare calls to these names (when not shadowed) skip SAVE/GVAR/CALLJ
    private static final Map<String, int[]> INTRINSICS = new HashMap<>();
    // int[] = { opcode ordinal, arity (-1 = variable) }
    static {
        INTRINSICS.put("car",  new int[]{ Opcode.CAR.ordinal(),     1 });
        INTRINSICS.put("cdr",  new int[]{ Opcode.CDR.ordinal(),     1 });
        INTRINSICS.put("cons", new int[]{ Opcode.CONS.ordinal(),    2 });
        INTRINSICS.put("null?",new int[]{ Opcode.IS_NULL.ordinal(), 1 });
        INTRINSICS.put("pair?",new int[]{ Opcode.IS_PAIR.ordinal(), 1 });
        INTRINSICS.put("not",  new int[]{ Opcode.NOT.ordinal(),     1 });
        INTRINSICS.put("+",    new int[]{ Opcode.ADD.ordinal(),    -1 });
        INTRINSICS.put("-",    new int[]{ Opcode.SUB.ordinal(),    -1 });
        INTRINSICS.put("*",    new int[]{ Opcode.MUL.ordinal(),    -1 });
        INTRINSICS.put("/",    new int[]{ Opcode.DIV.ordinal(),    -1 });
        INTRINSICS.put("=",    new int[]{ Opcode.NUM_EQ.ordinal(), -1 });
        INTRINSICS.put("<",    new int[]{ Opcode.NUM_LT.ordinal(), -1 });
        INTRINSICS.put(">",    new int[]{ Opcode.NUM_GT.ordinal(), -1 });
        INTRINSICS.put("<=",   new int[]{ Opcode.NUM_LTE.ordinal(),-1 });
        INTRINSICS.put(">=",   new int[]{ Opcode.NUM_GTE.ordinal(),-1 });
        INTRINSICS.put("eq?",  new int[]{ Opcode.EQ_P.ordinal(),   2 });
        INTRINSICS.put("eqv?", new int[]{ Opcode.EQV_P.ordinal(),  2 });
        INTRINSICS.put("vector-ref",  new int[]{ Opcode.VECTOR_REF.ordinal(),  2 });
        INTRINSICS.put("vector-set!", new int[]{ Opcode.VECTOR_SET.ordinal(),  3 });
        INTRINSICS.put("list", new int[]{ Opcode.LIST.ordinal(),   -1 });
        for (String name : CXR_NAMES)
            INTRINSICS.put(name, new int[]{ Opcode.CXR.ordinal(), 1 });
    }

    /**
     * The car/cdr steps of a c[ad]+r name as bits, first step lowest
     * (1 = cdr, 0 = car), above a leading 1: caddr -> 0b1011.
     */
    public static int cxrPath(String name) {
        int path = 1;
        for (int i = 1; i < name.length() - 1; i++)
            path = (path << 1) | (name.charAt(i) == 'd' ? 1 : 0);
        return path;
    }

    public Compiler(Modules modules) {
        this.modules = modules;
        this.bindingTable = modules.getBindingTable();
    }

    // A lambda bound by letrec/letrec* to a variable that is never set!:
    // inside its body the variable is the running closure, so a tail call
    // of it with the right argument count becomes LOOP (new frame + jump).
    private static final class SelfCall {
        final Object frame; final int index; final int nparams; final String label;
        SelfCall(Object frame, int index, int nparams, String label) {
            this.frame = frame; this.index = index; this.nparams = nparams; this.label = label;
        }
    }
    // set before compiling a letrec init that is a lambda; compLambda takes it
    private SelfCall pendingSelf;
    // the self call of the function whose body is being compiled, or null
    private SelfCall currentSelf;
    // counts the compLambda nesting, so that a loop jumps only within its function
    private int fnLevel;

    // A named let compiled as a loop (compLoop): the frame of its name.
    private static final class LoopInfo {
        final int nparams; final String label; final int owner;
        LoopInfo(int nparams, String label, int owner) {
            this.nparams = nparams; this.label = label; this.owner = owner;
        }
    }
    private final Map<Object, LoopInfo> loops = new IdentityHashMap<>();

    // A loop's name is used other than the prescan allowed: compile the
    // named let the ordinary way instead.
    private static final class LoopBailout extends RuntimeException {
        final Object frame;
        LoopBailout(Object frame) { super(null, null, false, false); this.frame = frame; }
    }

    private static Object frameAt(Object env, int depth) {
        for (int i = 0; i < depth; i++) env = Value.asPair(env).cdr;
        return Value.asPair(env).car;
    }

    /** The name of the core form x is, or null (function calls, non-pairs). */
    private String coreFormName(Object x) {
        if (!Value.isPair(x)) return null;
        Object head = Value.asPair(x).car;
        if (head instanceof SyntaxObject && ((SyntaxObject) head).isIdentifier()) {
            ResolvedBinding b = SyntaxObject.resolve((SyntaxObject) head, bindingTable);
            if (b != null && b.bindingKind == ResolvedBinding.Kind.CORE_FORM) return b.symbolName;
        }
        return null;
    }

    private static boolean isIdentifier(Object x) {
        return (x instanceof SyntaxObject && ((SyntaxObject) x).isIdentifier()) || Value.isSymbol(x);
    }

    /** Whether an identifier called name occurs in code x (quoted data aside). */
    private boolean mentions(Object x, String name) {
        while (true) {
            if (isIdentifier(x)) return name.equals(getIdName(x));
            if (!Value.isPair(x)) return false;
            if ("quote".equals(coreFormName(x))) return false;
            if (mentions(Value.asPair(x).car, name)) return true;
            x = Value.asPair(x).cdr;
        }
    }

    /** Whether a set! of an identifier called name occurs in code x. */
    private boolean setsName(Object x, String name) {
        while (true) {
            if (!Value.isPair(x)) return false;
            String core = coreFormName(x);
            if ("quote".equals(core)) return false;
            if ("set!".equals(core) && Value.isPair(Value.asPair(x).cdr)
                && name.equals(getIdName(Value.asPair(x).second())))
                return true;
            if (setsName(Value.asPair(x).car, name)) return true;
            x = Value.asPair(x).cdr;
        }
    }

    /**
     * Whether the named-let name occurs in x only as the operator of calls
     * with n arguments in tail position of the loop body (tail: x's value is
     * the body's). Decided by name, so shadowing and macro-renamed
     * identifiers make it fail rather than slip through.
     */
    private boolean onlyLoopCalls(Object x, String name, int n, boolean tail) {
        if (!tail) return !mentions(x, name);
        if (isIdentifier(x)) return !name.equals(getIdName(x));
        if (!Value.isPair(x)) return true;
        Pair p = Value.asPair(x);
        String core = coreFormName(x);
        if (core == null) {
            Object f = p.car;
            if (isIdentifier(f) && name.equals(getIdName(f))) {
                int argc = 0;
                for (Object a = p.cdr; a != Value.NIL; a = Value.asPair(a).cdr) {
                    if (!Value.isPair(a)) return false;
                    argc++;
                }
                return argc == n && !mentions(p.cdr, name);
            }
            return !mentions(x, name);
        }
        switch (core) {
            case "quote":
                return true;
            case "begin":
                return bodyOnlyLoopCalls(p.cdr, name, n);
            case "if": {
                Object rest = p.cdr;
                if (!Value.isPair(rest) || mentions(Value.asPair(rest).car, name)) return false;
                rest = Value.asPair(rest).cdr;
                while (rest != Value.NIL) {
                    if (!Value.isPair(rest) || !onlyLoopCalls(Value.asPair(rest).car, name, n, true)) return false;
                    rest = Value.asPair(rest).cdr;
                }
                return true;
            }
            case "let": case "let*": case "letrec": case "letrec*": {
                if (!Value.isPair(p.cdr)) return false;
                Object bindings = p.second();
                if (!Value.isPair(bindings) && bindings != Value.NIL) return false; // named let
                for (Object b = bindings; b != Value.NIL; b = Value.asPair(b).cdr) {
                    if (!Value.isPair(b) || !Value.isPair(Value.asPair(b).car)) return false;
                    Pair binding = Value.asPair(Value.asPair(b).car);
                    if (name.equals(getIdName(binding.car)) || mentions(binding.cdr, name)) return false;
                }
                return bodyOnlyLoopCalls(p.nthCdr(2), name, n);
            }
            default:
                return !mentions(x, name);
        }
    }

    private boolean bodyOnlyLoopCalls(Object body, String name, int n) {
        while (body != Value.NIL) {
            if (!Value.isPair(body)) return false;
            Pair p = Value.asPair(body);
            if (!onlyLoopCalls(p.car, name, n, p.cdr == Value.NIL)) return false;
            body = p.cdr;
        }
        return true;
    }

    /**
     * Create a SyntaxObject for a core form keyword with the current module scope,
     * so it resolves through the binding table (mirrors Expander.coreFormId).
     */
    private Object coreFormId(String name) {
        int moduleScope = modules.getCurrentModuleScope();
        return new SyntaxObject(Value.intern(name), ScopeSet.of(moduleScope), null);
    }

    /** Extract identifier name from a SyntaxObject or plain symbol. */
    private static String getIdName(Object x) {
        if (x instanceof SyntaxObject) {
            SyntaxObject stx = (SyntaxObject) x;
            if (stx.isIdentifier()) return stx.symbolName();
        }
        if (Value.isSymbol(x)) return Value.asSymbol(x);
        return null;
    }

    /**
     * Compare two identifiers for binding equivalence.
     * Two SyntaxObjects match via BoundIdEq (same name + same marks).
     * Plain symbols match by name. Mixed: compare by name.
     */
    private static boolean identifiersMatch(Object a, Object b) {
        if (a instanceof SyntaxObject && b instanceof SyntaxObject) {
            SyntaxObject sa = (SyntaxObject) a;
            SyntaxObject sb = (SyntaxObject) b;
            if (sa.isIdentifier() && sb.isIdentifier())
                return sa.symbolName().equals(sb.symbolName()) && sb.scopes.isSubsetOf(sa.scopes);
        }
        String na = getIdName(a);
        String nb = getIdName(b);
        return na != null && na.equals(nb);
    }

    /** Search a frame for an identifier. Returns index or Value.F. */
    private Object inFrameP(Object identifier, Object frame) {
        if (frame == Value.NIL) return Value.F;
        if (identifiersMatch(identifier, Value.asPair(frame).car)) return 0;
        Object p = inFrameP(identifier, Value.asPair(frame).cdr);
        if (!p.equals(Value.F)) return 1 + (int) p;
        return Value.F;
    }

    /** Search the env for an identifier. Returns (frame, index) or Value.F. */
    private Object inEnvP(Object identifier, Object env) {
        if (env == Value.NIL) return Value.F;
        Object f = inFrameP(identifier, Value.asPair(env).car);
        if (!f.equals(Value.F)) return Pair.list(0, f);
        Object e = inEnvP(identifier, Value.asPair(env).cdr);
        if (!e.equals(Value.F)) return Pair.list(1 + (int) Value.asPair(e).first(), Value.asPair(e).second());
        return Value.F;
    }

    private Object gen(SourcePos pos, Opcode opcode, Object... args) {
        return ((Pair) Pair.list(Pair.list2(opcode, args).withPos(pos))).withPos(pos);
    }

    private Object seq(SourcePos pos, Object... lists) {
        List<Object> result = new ArrayList<>();
        for (int i = 0; i < lists.length; i++) {
            Pair.appendToList(lists[i], result);
        }
        if (result.isEmpty()) return Value.NIL;
        return ((Pair) Pair.list(result.toArray())).withPos(pos);
    }

    private int labelNum = 1;

    private String genLabel() {
        return genLabel("L");
    }

    private String genLabel(String prefix) {
        return prefix + labelNum++;
    }

    /**
     * The (frame var) of a local identifier, directly or through the binding
     * table (cross-scope references), or #f.
     */
    private Object resolveLocal(Object identifier, Object env) {
        Object p = inEnvP(identifier, env);
        if (!p.equals(Value.F)) return p;
        if (identifier instanceof SyntaxObject) {
            var binding = SyntaxObject.resolve((SyntaxObject) identifier, bindingTable);
            if (binding != null && binding.bindingKind == ResolvedBinding.Kind.LOCAL && binding.value instanceof SyntaxObject)
                return inEnvP(binding.value, env);
        }
        return Value.F;
    }

    // A reference to a loop's name other than a loop call
    private void checkNotLoop(Object p, Object env) {
        if (loops.isEmpty()) return;
        Object frame = frameAt(env, (int) Value.asPair(p).first());
        if (loops.containsKey(frame)) throw new LoopBailout(frame);
    }

    /** Generate variable access for any identifier (SyntaxObject or plain symbol). */
    private Object genVar(SourcePos pos, Object identifier, Object env) {
        String name = getIdName(identifier);
        Object p = resolveLocal(identifier, env);
        if (!p.equals(Value.F)) {
            checkNotLoop(p, env);
            return gen(pos, Opcode.LVAR, Value.asPair(p).first(), Value.asPair(p).second(), ";", name);
        }
        // Not local → resolve through binding table or fall back to current module
        if (identifier instanceof SyntaxObject) {
            SyntaxObject idStx = (SyntaxObject) identifier;

            var binding = SyntaxObject.resolve(idStx, bindingTable);
            if (binding != null && binding.moduleName != null)
                return gen(pos, Opcode.GVAR, binding.symbolName, binding.moduleName);
        }
        return gen(pos, Opcode.GVAR, name != null ? name : "?", modules.getCurrentModule().getName());
    }

    /** Generate variable set for any identifier. */
    private Object genSet(SourcePos pos, Object identifier, Object env) {
        String name = getIdName(identifier);
        Object p = resolveLocal(identifier, env);
        if (!p.equals(Value.F)) {
            checkNotLoop(p, env);
            return gen(pos, Opcode.LSET, Value.asPair(p).first(), Value.asPair(p).second(), ";", name);
        }
        if (identifier instanceof SyntaxObject) {
            SyntaxObject idStx = (SyntaxObject) identifier;

            var binding = SyntaxObject.resolve(idStx, bindingTable);
            if (binding != null && binding.moduleName != null)
                return gen(pos, Opcode.GSET, binding.symbolName, binding.moduleName);
        }
        return gen(pos, Opcode.GSET, name != null ? name : "?", modules.getCurrentModule().getName());
    }

    private Object comp(SourcePos pos, Object x, Object env, boolean val, boolean more) {
        // In the sets-of-scopes model, SyntaxObjects only wrap identifiers.
        // If we see a SyntaxObject, it's always an identifier reference.
        if (x instanceof SyntaxObject) {
            SyntaxObject stx = (SyntaxObject) x;
            pos = stx.pos != null ? stx.pos : pos;
            if (stx.isIdentifier()) {
                return compVar(pos, stx, env, val, more);
            }
            // Non-identifier SyntaxObject should not occur in sets-of-scopes model,
            // but handle gracefully by stripping
            x = SyntaxObject.strip(stx);
        }
        if (x == null) return compConst(pos, Value.F, val, more); // null treated as unspecified
        if (x == Value.T || x == Value.F) return compConst(pos, x, val, more);
        if (Value.isSymbol(x)) return compVar(pos, Value.asSymbol(x), env, val, more);
        if (Value.isAtom(x)) return compConst(pos, x, val, more);
        if (Value.isVector(x)) return compConst(pos, SyntaxObject.strip(x), val, more);
        if (Value.isValues(x)) return compConst(pos, x, val, more);
        if (x == Value.NIL) return compConst(pos, Value.NIL, val, more);
        if (Value.asPair(x).pos != null) pos = Value.asPair(x).pos;
        Object first = Value.asPair(x).first();
        // Keep the original first element (may be SyntaxObject) for compFuncall
        Object firstOriginal = first;
        // Resolve the head to determine if it's a core form or a variable reference.
        // The Expander emits core forms as SyntaxObjects that resolve to CoreForm bindings.
        // If the head resolves to a CoreForm, dispatch to the core form handler.
        // Otherwise (variable reference, unresolved), compile as a function call.
        String firstStr = "";
        if (first instanceof SyntaxObject && ((SyntaxObject) first).isIdentifier()) {
            SyntaxObject firstStx = (SyntaxObject) first;
            ResolvedBinding binding = SyntaxObject.resolve(firstStx, bindingTable);
            if (binding != null && binding.bindingKind == ResolvedBinding.Kind.CORE_FORM)
                firstStr = binding.symbolName;
            else
                return compFuncall(Value.asPair(x).pos != null ? Value.asPair(x).pos : pos, firstOriginal, Value.asPair(x).cdr, env, val, more);
        } else if (Value.isSymbol(first)) {
            throw new SchemeError(pos, "compiler: unexpected plain symbol in head position: ~a", first);
        }
        if (firstStr.equals("quote")) {
            Object quotedDatum = SyntaxObject.strip(Value.asPair(x).second());
            return compConst(pos, quotedDatum, val, more);
        }
        if (firstStr.equals("begin")) return compBegin(pos, Value.asPair(x).cdr, env, val, more);
        if (firstStr.equals("define")) {
            // (define name value) -> (begin (set! name value) 'name)
            // (define (name args...) body...) -> (define name (lambda (args...) body...))
            Object second = Value.asPair(x).second();
            // In sets-of-scopes, SyntaxObjects only wrap identifiers, so second
            // is either a SyntaxObject identifier or a plain Pair
            Object secondExposed = second;
            if (Value.isPair(secondExposed)) {
                // (define (name args...) body...) -> rewrite as (define name (lambda (args...) body...))
                Object nameId = Value.asPair(secondExposed).first();
                Object args = Value.asPair(secondExposed).cdr;
                Object body = Value.asPair(x).nthCdr(2);
                Object lambda = new Pair(coreFormId("lambda"), new Pair(args, body));
                Object rewritten = Pair.list(coreFormId("define"), nameId, lambda);
                return comp(pos, rewritten, env, val, more);
            } else {
                // (define name value) -> (begin (set! name value) 'name)
                Object value = Value.asPair(x).third();
                Object setForm = Pair.list(coreFormId("set!"), secondExposed, value);
                Object result = Pair.list(coreFormId("begin"), setForm, Pair.list(coreFormId("quote"), SyntaxObject.strip(secondExposed)));
                return comp(pos, result, env, val, more);
            }
        }
        if (firstStr.equals("set!")) {
            Object setVar = Value.asPair(x).second();
            // Unwrap SyntaxObject wrapper on the variable
            if (setVar instanceof SyntaxObject) {
                SyntaxObject setStx = (SyntaxObject) setVar;
                if (setStx.isIdentifier()) {
                    // Keep as SyntaxObject -- genSet handles it
                }
            } else if (!Value.isSymbol(setVar)) {
                throw new SchemeError(pos, "set!: variable must be a symbol, got ~a", setVar);
            }
            return seq(pos,
                       comp(pos, Value.asPair(x).third(), env, true, true),
                       genSet(pos, setVar, env),
                       val ? Value.NIL : gen(pos, Opcode.POP),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        }
        if (firstStr.equals("if")) {
            if (Value.asPair(x).length() == 4) {
                return compIf(pos,
                              Value.asPair(x).second(),
                              Value.asPair(x).third(),
                              Value.asPair(x).fourth(),
                              env, val, more);
            } else {
                return compIf(pos,
                              Value.asPair(x).second(),
                              Value.asPair(x).third(),
                              new Values(),
                              env, val, more);
            }
        }
        if (firstStr.equals("lambda")) {
            if (!val) return Value.NIL;
            // Internal definitions are handled by the Expander (ExpandBody -> letrec*)
            Pair f = compLambda(Value.asPair(x).pos,
                                Value.asPair(x).second(),
                                Value.asPair(x).nthCdr(2),
                                env);
            return seq(pos,
                       gen(pos, Opcode.FN, f),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        }
        if (firstStr.equals("let")) {
            return compLet(pos, x, env, val, more);
        }
        if (firstStr.equals("let*")) {
            return compLetStar(pos, x, env, val, more);
        }
        if (firstStr.equals("letrec")) {
            return compLetrec(pos, x, env, val, more);
        }
        if (firstStr.equals("letrec*")) {
            return compLetrecStar(pos, x, env, val, more);
        }
        return compFuncall(Value.asPair(x).pos != null ? Value.asPair(x).pos : pos,
                           firstOriginal,
                           Value.asPair(x).cdr,
                           env, val, more);
    }

    private Object compBegin(SourcePos pos, Object exps, Object env, boolean val, boolean more) {
        if (exps == Value.NIL) {
            return compConst(pos, Value.NIL, val, more);
        }
        if (!Value.isPair(exps))
            throw new SchemeError(pos, "improper list in begin");

        // All macros and define-syntax are handled by the Expander.
        // The Compiler just compiles the expanded forms sequentially.
        Object firstForm = Value.asPair(exps).first();

        if (Value.asPair(exps).cdr == Value.NIL) {
            return comp(pos, firstForm, env, val, more);
        }
        return seq(pos,
                   comp(pos, firstForm, env, false, true),
                   compBegin(pos, Value.asPair(exps).cdr, env, val, more));
    }

    private Object compList(SourcePos pos, Object exps, Object env) {
        if (exps == Value.NIL) return Value.NIL;
        if (!Value.isPair(exps))
            throw new SchemeError(pos, "improper list in function call");
        return seq(pos,
                   comp(pos, Value.asPair(exps).first(), env, true, true),
                   compList(pos, Value.asPair(exps).cdr, env));
    }

    private Object compConst(SourcePos pos, Object x, boolean val, boolean more) {
        if (val) {
            return seq(pos,
                       gen(pos, Opcode.CONST, x),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        } else {
            return Value.NIL;
        }
    }

    /** Compile a variable reference from any identifier type. */
    private Object compVar(SourcePos pos, Object identifier, Object env,
                         boolean val, boolean more) {
        if (val) {
            return seq(pos,
                       genVar(pos, identifier, env),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        } else {
            return Value.NIL;
        }
    }

    private Object compIf(SourcePos pos, Object pred, Object then,
                        Object alternative, Object env, boolean val,
                        boolean more) {
        if (pred.equals(Value.F)) return comp(pos, alternative, env, val, more);
        if (Value.isConstant(pred)) return comp(pos, then, env, val, more);
        Object pcode = comp(pos, pred, env, true, true);
        Object tcode = comp(pos, then, env, val, more);
        Object ecode = comp(pos, alternative, env, val, more);
        // Case A: both branches empty -- only evaluate predicate for side effects
        if (tcode == Value.NIL && ecode == Value.NIL)
            return comp(pos, pred, env, false, more);
        // Case B: then-branch empty -- use TJUMP to skip over else
        if (tcode == Value.NIL) {
            String l2 = genLabel();
            return seq(pos, pcode, gen(pos, Opcode.TJUMP, l2), ecode, Pair.list(l2),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        }
        // Case C: else-branch empty -- use FJUMP to skip over then
        if (ecode == Value.NIL) {
            String l1 = genLabel();
            return seq(pos, pcode, gen(pos, Opcode.FJUMP, l1), tcode, Pair.list(l1),
                       more ? Value.NIL : gen(pos, Opcode.RETURN));
        }
        // Generic case
        String gl1 = genLabel();
        String gl2 = more ? genLabel() : null;
        return seq(pos,
                   pcode,
                   gen(pos, Opcode.FJUMP, gl1),
                   tcode,
                   more ? gen(pos, Opcode.JUMP, gl2) : Value.NIL,
                   Pair.list(gl1),
                   ecode,
                   more ? Pair.list(gl2) : Value.NIL);
    }

    private Object compFuncall(SourcePos pos, Object f, Object args,
                             Object env, boolean val, boolean more) {
        String fName = getIdName(f);

        if (Value.isPair(f)) {
            Object fHead = Value.asPair(f).first();
            String fHeadName = getIdName(fHead);
            if (fHeadName == null) fHeadName = Value.isSymbol(fHead) ? Value.asSymbol(fHead) : "";
            Object fParams = Value.asPair(f).cdr != Value.NIL ? Value.asPair(f).second() : Value.NIL;
            if (fHeadName.equals("lambda") && fParams == Value.NIL) {
                // ((lambda () body)) ==> (begin body)
                return compBegin(pos, Value.asPair(f).nthCdr(2), env, val, more);
            }
            // ((lambda (x y ...) body) a b ...) ==> inline with EXTEND
            if (fHeadName.equals("lambda")
                && fParams != Value.NIL
                && isSimpleParamList(fParams)) {
                int paramCount = Value.asPair(fParams).length();
                int argCount = (args == Value.NIL ? 0 : Value.asPair(args).length());
                if (paramCount == argCount) {
                    Object body = Value.asPair(f).nthCdr(2);
                    if (body != Value.NIL && Value.isPair(body)
                        && Value.asPair(body).cdr != Value.NIL
                        && Value.asPair(body).car instanceof char[])
                        body = Value.asPair(body).cdr;
                    Pair newEnv = new Pair(makeTrueList(fParams), env);
                    if (more) {
                        return seq(pos,
                            compList(pos, args, env),
                            gen(pos, Opcode.EXTEND, paramCount),
                            compBegin(pos, body, newEnv, val, true),
                            gen(pos, Opcode.POPENV));
                    }
                    return seq(pos,
                        compList(pos, args, env),
                        gen(pos, Opcode.EXTEND, paramCount),
                        compBegin(pos, body, newEnv, true, false));
                }
            }
        }
        // A loop call of a named let compiled by compLoop, or a self tail call
        if (fName != null && (!loops.isEmpty() || (!more && currentSelf != null))) {
            Object p = resolveLocal(f, env);
            if (!p.equals(Value.F)) {
                int depth = (int) Value.asPair(p).first(), index = (int) Value.asPair(p).second();
                int argc = (args == Value.NIL ? 0 : Value.asPair(args).length());
                Object frame = frameAt(env, depth);
                LoopInfo loop = loops.get(frame);
                String label = null;
                if (loop != null) {
                    if (index != 0 || loop.owner != fnLevel || argc != loop.nparams)
                        throw new LoopBailout(frame);
                    label = loop.label;
                } else if (!more && currentSelf != null && currentSelf.frame == frame
                           && currentSelf.index == index && currentSelf.nparams == argc) {
                    label = currentSelf.label;
                }
                if (label != null)
                    return seq(pos, compList(pos, args, env), gen(pos, Opcode.LOOP, argc, depth, label));
            }
        }
        // Intrinsic: identifier not shadowed locally and still bound to the original primitive
        if (fName != null) {
            // For SyntaxObjects, resolve through wraps to find the original binding
            String intrinsicName = fName;
            String intrinsicModule = null;
            if (f instanceof SyntaxObject) {
                SyntaxObject fIdStx = (SyntaxObject) f;
                ResolvedBinding binding = SyntaxObject.resolve(fIdStx, bindingTable);
                if (binding != null && binding.moduleName != null) {
                    intrinsicName = binding.symbolName;
                    intrinsicModule = binding.moduleName;
                }
            }
            // Check if the identifier is locally bound (including cross-scope via binding table)
            boolean isLocallyBound = !inEnvP(f, env).equals(Value.F);
            if (!isLocallyBound && f instanceof SyntaxObject) {
                SyntaxObject fStx2 = (SyntaxObject) f;
                var b = SyntaxObject.resolve(fStx2, bindingTable);
                isLocallyBound = b != null && b.bindingKind == ResolvedBinding.Kind.LOCAL;
            }
            int[] info = INTRINSICS.get(intrinsicName);
            if (info != null && !isLocallyBound) {
                // Check the binding still points to a primitive
                boolean isPrimitive;
                if (intrinsicModule != null) {
                    Module mod = modules.getModule(intrinsicModule);
                    isPrimitive = mod != null && mod.isBound(intrinsicName)
                        && mod.resolve(pos, intrinsicName) instanceof Primitive;
                } else {
                    isPrimitive = !modules.getCurrentModule().isBound(fName)
                        || modules.getCurrentModule().resolve(pos, fName) instanceof Primitive;
                }
                if (isPrimitive) {
                    int argc = (args == Value.NIL ? 0 : Value.asPair(args).length());
                    if (info[1] == -1 || argc == info[1]) {
                        Opcode op = Opcode.values()[info[0]];
                        Object opInstr = op == Opcode.CXR
                            ? gen(pos, op, cxrPath(intrinsicName), intrinsicName)
                            : gen(pos, op, argc);
                        if (more) {
                            return seq(pos,
                                       compList(pos, args, env),
                                       opInstr,
                                       val ? Value.NIL : gen(pos, Opcode.POP));
                        }
                        return seq(pos,
                                   compList(pos, args, env),
                                   opInstr,
                                   gen(pos, Opcode.RETURN));
                    }
                }
            }
        }
        if (more) {
            // CALLS puts the return address under the arguments itself,
            // and only when f is a lambda (a primitive just returns)
            return seq(pos,
                       compList(pos, args, env),
                       comp(pos, f, env, true, true),
                       gen(pos, Opcode.CALLS, (args == Value.NIL ? 0 : Value.asPair(args).length())),
                       val ? Value.NIL : gen(pos, Opcode.POP));
        }
        return seq(pos,
                   compList(pos, args, env),
                   comp(pos, f, env, true, true),
                   gen(pos, Opcode.CALLJ, (args == Value.NIL ? 0 : Value.asPair(args).length())));
    }

    private Pair compLambda(SourcePos pos, Object args, Object body, Object env) {
        // Detect and strip docstring: first form is a string literal and body has more forms
        String docstring = null;
        if (body != Value.NIL
                && Value.isPair(body)
                && Value.asPair(body).cdr != Value.NIL
                && Value.asPair(body).car instanceof char[]) {
            docstring = new String((char[]) Value.asPair(body).car);
            body = Value.asPair(body).cdr;
        }

        SelfCall self = pendingSelf;
        pendingSelf = null;
        SelfCall outerSelf = currentSelf;
        currentSelf = self;
        fnLevel++;
        Object code;
        try {
            code = optimize(seq(pos,
                                genArgs(pos, args, 0),
                                self != null ? Pair.list(self.label) : Value.NIL,
                                compBegin(pos,
                                          body,
                                          new Pair(makeTrueList(args), env),
                                          true,
                                          false)));
        } finally {
            currentSelf = outerSelf;
            fnLevel--;
        }

        Pair fn;
        if (docstring != null) {
            fn = ((Pair) Pair.list(Value.intern("env:"), env,
                           Value.intern("args:"), args,
                           Value.intern("code:"), code,
                           Value.intern("doc:"), docstring)).withPos(pos);
        } else {
            fn = ((Pair) Pair.list(Value.intern("env:"), env,
                           Value.intern("args:"), args,
                           Value.intern("code:"), code)).withPos(pos);
        }
        return assemble(fn);
    }

    /** Compile (let ((var val) ...) body ...) and named let. */
    private Object compLet(SourcePos pos, Object x, Object env, boolean val, boolean more) {
        Object second = Value.asPair(x).second();
        // Check for named let: (let name ((var val) ...) body ...)
        String nameStr = getIdName(second);
        if (nameStr != null && !Value.isPair(second)) {
            // Named let: rewrite to ((letrec ((name (lambda (vars...) body...))) name) vals...)
            Object bindings = Value.asPair(x).third();
            Object body = Value.asPair(x).nthCdr(3);
            ArrayList<Object> vars = new ArrayList<>();
            ArrayList<Object> vals = new ArrayList<>();
            extractBindings(bindings, vars, vals);
            Object varList = Pair.list(vars.toArray());
            if (isSimpleParamList(varList) && bodyOnlyLoopCalls(body, nameStr, vars.size())) {
                Object nameFrame = Pair.list(second);
                try {
                    return compLoop(pos, nameFrame, varList, vals, body, env, val, more);
                } catch (LoopBailout b) {
                    if (b.frame != nameFrame) throw b;
                }
            }
            // Build (lambda (vars...) body...)
            ArrayList<Object> lambdaParts = new ArrayList<>();
            lambdaParts.add(coreFormId("lambda"));
            lambdaParts.add(varList);
            Object cur = body;
            while (cur != Value.NIL && Value.isPair(cur)) { lambdaParts.add(Value.asPair(cur).car); cur = Value.asPair(cur).cdr; }
            Object lambdaForm = Pair.list(lambdaParts.toArray());
            // Build ((letrec ((name lambda)) name) vals...)
            Object letrecForm = Pair.list(coreFormId("letrec"),
                Pair.list(Pair.list(second, lambdaForm)),
                second);
            Object callForm = new Pair(letrecForm, Pair.list(vals.toArray()));
            return comp(pos, callForm, env, val, more);
        } else {
            // Simple let: compile as inline with EXTEND
            Object bindings = second;
            Object body = Value.asPair(x).nthCdr(2);
            ArrayList<Object> vars = new ArrayList<>();
            ArrayList<Object> vals = new ArrayList<>();
            extractBindings(bindings, vars, vals);

            // Inline optimization: use EXTEND instead of creating a closure
            int n = vars.size();
            Pair newEnv = new Pair(Pair.list(vars.toArray()), env);
            if (n == 1 && (val || more)) {
                Object orCode = compOrTemp(pos, vals.get(0), body, newEnv, env, val, more);
                if (orCode != null) return orCode;
            }
            if (more) {
                return seq(pos,
                    compList(pos, Pair.list(vals.toArray()), env),
                    gen(pos, Opcode.EXTEND, n),
                    compBegin(pos, body, newEnv, val, true),
                    gen(pos, Opcode.POPENV));
            }
            return seq(pos,
                compList(pos, Pair.list(vals.toArray()), env),
                gen(pos, Opcode.EXTEND, n),
                compBegin(pos, body, newEnv, true, false));
        }
    }

    /**
     * A named let whose name is only called in tail position of its body
     * (bodyOnlyLoopCalls) as a loop: no closure and no call, each loop call
     * binds a new frame of the variables and jumps back. The frame of the
     * name stays (holding #f) so that the body's variable indexes are those
     * of the ordinary letrec rewrite.
     */
    private Object compLoop(SourcePos pos, Object nameFrame, Object varList, List<Object> vals,
                            Object body, Object env, boolean val, boolean more) {
        int n = vals.size();
        Object bodyEnv = new Pair(varList, new Pair(nameFrame, env));
        String top = genLabel();
        loops.put(nameFrame, new LoopInfo(n, top, fnLevel));
        try {
            Object start = seq(pos,
                compList(pos, Pair.list(vals.toArray()), env),
                gen(pos, Opcode.CONST, Value.F),
                gen(pos, Opcode.EXTEND, 1),
                gen(pos, Opcode.EXTEND, n),
                Pair.list(top));
            if (more) {
                return seq(pos, start,
                    compBegin(pos, body, bodyEnv, val, true),
                    gen(pos, Opcode.POPENV),
                    gen(pos, Opcode.POPENV));
            }
            return seq(pos, start, compBegin(pos, body, bodyEnv, true, false));
        } finally {
            loops.remove(nameFrame);
        }
    }

    /**
     * (let ((t e1)) (if t t e2)) with t not in e2 -- what or expands to --
     * without the frame: e1 TJUMP_KEEP L e2 L. Null if body is not that.
     */
    private Object compOrTemp(SourcePos pos, Object e1, Object body, Object newEnv, Object env,
                              boolean val, boolean more) {
        if (!Value.isPair(body) || Value.asPair(body).cdr != Value.NIL) return null;
        Object form = Value.asPair(body).car;
        if (!"if".equals(coreFormName(form)) || Value.asPair(form).length() != 4) return null;
        Pair ifForm = Value.asPair(form);
        String tName = getIdName(Value.asPair(Value.asPair(newEnv).car).car);
        Object test = ifForm.second(), then = ifForm.third(), e2 = ifForm.fourth();
        if (tName == null || !isIdentifier(test) || !isIdentifier(then) || mentions(e2, tName)) return null;
        if (!isFirstLocal(resolveLocal(test, newEnv)) || !isFirstLocal(resolveLocal(then, newEnv))) return null;
        String l = genLabel();
        if (!val) {
            return seq(pos,
                comp(pos, e1, env, true, true),
                gen(pos, Opcode.TJUMP, l),
                comp(pos, e2, env, false, true),
                Pair.list(l));
        }
        return seq(pos,
            comp(pos, e1, env, true, true),
            gen(pos, Opcode.TJUMP_KEEP, l),
            comp(pos, e2, env, true, more),
            Pair.list(l),
            more ? Value.NIL : gen(pos, Opcode.RETURN));
    }

    private static boolean isFirstLocal(Object p) {
        return !p.equals(Value.F) && (int) Value.asPair(p).first() == 0 && (int) Value.asPair(p).second() == 0;
    }

    /**
     * The self call of letrec variable index of frame bound to init, when init
     * is a lambda with a plain parameter list and the letrec form x never
     * set!s the variable; else null.
     */
    private SelfCall selfCallFor(Object x, Object frame, int index, Object var, Object init) {
        if (!"lambda".equals(coreFormName(init))) return null;
        Pair lambda = Value.asPair(init);
        if (!Value.isPair(lambda.cdr)) return null;
        Object params = lambda.second();
        String name = getIdName(var);
        if (name == null || !isSimpleParamList(params) || setsName(x, name)) return null;
        int n = params == Value.NIL ? 0 : Value.asPair(params).length();
        return new SelfCall(frame, index, n, genLabel());
    }

    /** Compile (let* ((var val) ...) body ...) as nested lets. */
    private Object compLetStar(SourcePos pos, Object x, Object env, boolean val, boolean more) {
        Object bindings = Value.asPair(x).second();
        Object body = Value.asPair(x).nthCdr(2);

        if (bindings == Value.NIL) {
            // (let* () body...) = (begin body...)
            return compBegin(pos, body, env, val, more);
        }

        // Compile first binding, then recurse
        Object firstBinding = Value.asPair(bindings).car;
        if (!Value.isPair(firstBinding))
            throw new SchemeError(pos, "let*: invalid binding");
        Object variable = Value.asPair(firstBinding).car;
        Object varCdr = Value.asPair(firstBinding).cdr;
        Object valExpr = Value.isPair(varCdr) ? Value.asPair(varCdr).car : Value.F;
        Object restBindings = Value.asPair(bindings).cdr;

        // Build inner let*
        ArrayList<Object> innerParts = new ArrayList<>();
        innerParts.add(coreFormId("let*"));
        innerParts.add(restBindings);
        Object cur = body;
        while (cur != Value.NIL && Value.isPair(cur)) { innerParts.add(Value.asPair(cur).car); cur = Value.asPair(cur).cdr; }

        // Compile as (let ((var val)) (let* rest body))
        Pair newEnv = new Pair(Pair.list(variable), env);
        if (more) {
            return seq(pos,
                comp(pos, valExpr, env, true, true),
                gen(pos, Opcode.EXTEND, 1),
                comp(pos, Pair.list(innerParts.toArray()), newEnv, val, true),
                gen(pos, Opcode.POPENV));
        }
        return seq(pos,
            comp(pos, valExpr, env, true, true),
            gen(pos, Opcode.EXTEND, 1),
            comp(pos, Pair.list(innerParts.toArray()), newEnv, true, false));
    }

    /**
     * Compile (letrec ((var val) ...) body ...).
     * R7RS 4.2.2: evaluate ALL init expressions first, then assign all results.
     */
    private Object compLetrec(SourcePos pos, Object x, Object env, boolean val, boolean more) {
        Object bindings = Value.asPair(x).second();
        Object body = Value.asPair(x).nthCdr(2);

        ArrayList<Object> vars = new ArrayList<>();
        ArrayList<Object> valExprs = new ArrayList<>();
        extractBindings(bindings, vars, valExprs);

        int n = vars.size();
        if (n == 0)
            return compBegin(pos, body, env, val, more);

        Object newEnv = new Pair(Pair.list(vars.toArray()), env);

        // Push #f placeholders, EXTEND to create the frame
        Object initCode = Value.NIL;
        for (int i = 0; i < n; i++)
            initCode = seq(pos, initCode, gen(pos, Opcode.CONST, Value.F));
        initCode = seq(pos, initCode, gen(pos, Opcode.EXTEND, n));

        // Evaluate ALL init expressions onto the stack
        Object evalCode = Value.NIL;
        Object frame = Value.asPair(newEnv).car;
        for (int i = 0; i < n; i++) {
            pendingSelf = selfCallFor(x, frame, i, vars.get(i), valExprs.get(i));
            try {
                evalCode = seq(pos, evalCode,
                    comp(pos, valExprs.get(i), newEnv, true, true));
            } finally {
                pendingSelf = null;
            }
        }

        // Assign all at once in reverse order (last value is on top of stack)
        Object setCode = Value.NIL;
        for (int i = n - 1; i >= 0; i--) {
            String varName = getIdName(vars.get(i));
            setCode = seq(pos, setCode,
                gen(pos, Opcode.LSET, 0, i, ";", varName != null ? varName : "?"),
                gen(pos, Opcode.POP));
        }

        if (more) {
            return seq(pos,
                initCode, evalCode, setCode,
                compBegin(pos, body, newEnv, val, true),
                gen(pos, Opcode.POPENV));
        }
        return seq(pos,
            initCode, evalCode, setCode,
            compBegin(pos, body, newEnv, true, false));
    }

    /**
     * Compile (letrec* ((var val) ...) body ...).
     * R7RS 4.2.2: evaluate and assign sequentially left-to-right.
     */
    private Object compLetrecStar(SourcePos pos, Object x, Object env, boolean val, boolean more) {
        Object bindings = Value.asPair(x).second();
        Object body = Value.asPair(x).nthCdr(2);

        ArrayList<Object> vars = new ArrayList<>();
        ArrayList<Object> valExprs = new ArrayList<>();
        extractBindings(bindings, vars, valExprs);

        int n = vars.size();
        if (n == 0)
            return compBegin(pos, body, env, val, more);

        Object newEnv = new Pair(Pair.list(vars.toArray()), env);

        // Push #f placeholders, EXTEND to create the frame
        Object initCode = Value.NIL;
        for (int i = 0; i < n; i++)
            initCode = seq(pos, initCode, gen(pos, Opcode.CONST, Value.F));
        initCode = seq(pos, initCode, gen(pos, Opcode.EXTEND, n));

        // Evaluate and assign each binding sequentially
        Object setCode = Value.NIL;
        Object frame = Value.asPair(newEnv).car;
        for (int i = 0; i < n; i++) {
            String varName = getIdName(vars.get(i));
            pendingSelf = selfCallFor(x, frame, i, vars.get(i), valExprs.get(i));
            Object valCode;
            try {
                valCode = comp(pos, valExprs.get(i), newEnv, true, true);
            } finally {
                pendingSelf = null;
            }
            setCode = seq(pos, setCode,
                valCode,
                gen(pos, Opcode.LSET, 0, i, ";", varName != null ? varName : "?"),
                gen(pos, Opcode.POP));
        }

        if (more) {
            return seq(pos,
                initCode, setCode,
                compBegin(pos, body, newEnv, val, true),
                gen(pos, Opcode.POPENV));
        }
        return seq(pos,
            initCode, setCode,
            compBegin(pos, body, newEnv, true, false));
    }

    /** Extract vars and vals from a binding list ((var val) ...). */
    private void extractBindings(Object bindings, ArrayList<Object> vars, ArrayList<Object> vals) {
        Object cur = bindings;
        while (cur != Value.NIL && Value.isPair(cur)) {
            Object binding = Value.asPair(cur).car;
            if (Value.isPair(binding)) {
                vars.add(Value.asPair(binding).car);
                Object bindCdr = Value.asPair(binding).cdr;
                vals.add(Value.isPair(bindCdr) ? Value.asPair(bindCdr).car : Value.F);
            }
            cur = Value.asPair(cur).cdr;
        }
    }

    private Object genArgs(SourcePos pos, Object args, int nsofar) {
        // SyntaxObject identifier = rest parameter
        if (args instanceof SyntaxObject) {
            SyntaxObject sArgs = (SyntaxObject) args;
            if (sArgs.isIdentifier()) return gen(pos, Opcode.ARGSDOT, nsofar);
            // Non-identifier SyntaxObject should not occur; treat as rest param
            return gen(pos, Opcode.ARGSDOT, nsofar);
        }
        if (args == Value.NIL) return gen(pos, Opcode.ARGS, nsofar);
        if (Value.isSymbol(args)) return gen(pos, Opcode.ARGSDOT, nsofar);
        if (Value.isPair(args)) {
            Object first = Value.asPair(args).first();
            if (Value.isSymbol(first) || (first instanceof SyntaxObject && ((SyntaxObject) first).isIdentifier()))
                return genArgs(pos, Value.asPair(args).cdr, 1 + nsofar);
        }
        throw new SchemeError(pos, "Illegal argument list");
    }

    private Object makeTrueList(Object dottedList) {
        // SyntaxObject identifier = rest parameter
        if (dottedList instanceof SyntaxObject) {
            SyntaxObject sDl = (SyntaxObject) dottedList;
            if (sDl.isIdentifier()) return Pair.list(dottedList); // rest param
            // Non-identifier SyntaxObject should not occur; treat as atom
            return Pair.list(dottedList);
        }
        if (dottedList == Value.NIL) return Value.NIL;
        if (Value.isAtom(dottedList)) return Pair.list(dottedList);
        if (Value.isPair(dottedList))
            return new Pair(
                Value.asPair(dottedList).first(),
                makeTrueList(Value.asPair(dottedList).cdr));
        return Pair.list(dottedList);
    }

    private static boolean isSimpleParamList(Object paramList) {
        Object cur = paramList;
        while (cur != Value.NIL) {
            if (cur instanceof SyntaxObject && ((SyntaxObject) cur).isIdentifier()) return false; // rest param
            if (!Value.isPair(cur)) return false; // dotted/rest param
            Object param = Value.asPair(cur).car;
            if (!Value.isSymbol(param) && !(param instanceof SyntaxObject && ((SyntaxObject) param).isIdentifier()))
                return false;
            cur = Value.asPair(cur).cdr;
        }
        return true;
    }

    private Object optimize(Object code) {
        List<Object> items = new ArrayList<>();
        Object cur = code;
        while (cur != Value.NIL) { items.add(Value.asPair(cur).car); cur = Value.asPair(cur).cdr; }

        boolean changed = true;
        while (changed) {
            changed  = peepholeDeadCode(items);
            changed |= peepholeUselessJumps(items);
            changed |= peepholeLoadPop(items);
            changed |= peepholeJumpToReturn(items);
            changed |= peepholeNotBranch(items);
            changed |= peepholeConstBranch(items);
            changed |= peepholeJumpThread(items);
            changed |= peepholeUnusedLabels(items);
            changed |= peepholeLocalAddImm(items);
            changed |= peepholeKeepBranch(items);
        }
        peepholeFuse(items);
        return items.isEmpty() ? Value.NIL : Pair.list(items.toArray());
    }

    private static boolean isInstr(Object item) { return Value.isPair(item); }
    private static boolean isLabel(Object item) { return Value.isSymbol(item); }
    private static Opcode getOp(Object item) { return (Opcode) Value.asPair(item).car; }
    private static String getTarget(Object item) { return (String) Value.asPair(item).second(); }

    // Pass A: Remove dead code after RETURN or JUMP (until next label)
    private static boolean peepholeDeadCode(List<Object> items) {
        boolean changed = false;
        int i = 0;
        while (i < items.size()) {
            if (isInstr(items.get(i)) && (getOp(items.get(i)) == Opcode.RETURN || getOp(items.get(i)) == Opcode.JUMP
                                          || getOp(items.get(i)) == Opcode.LOOP)) {
                int j = i + 1;
                while (j < items.size() && isInstr(items.get(j))) {
                    items.remove(j);
                    changed = true;
                }
            }
            i++;
        }
        return changed;
    }

    // Pass B: Remove or replace jump to immediately-following label
    private static boolean peepholeUselessJumps(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i < items.size(); i++) {
            if (!isInstr(items.get(i))) continue;
            Opcode op = getOp(items.get(i));
            if (op != Opcode.JUMP && op != Opcode.FJUMP && op != Opcode.TJUMP) continue;
            String target = getTarget(items.get(i));
            if (i + 1 < items.size() && isLabel(items.get(i + 1)) && items.get(i + 1).equals(target)) {
                if (op == Opcode.JUMP) {
                    items.remove(i);
                    i--;
                } else {
                    items.set(i, Pair.list((Object) Opcode.POP));
                }
                changed = true;
            }
        }
        return changed;
    }

    // Pass C: Remove CONST/LVAR/GVAR immediately followed by POP
    private static boolean peepholeLoadPop(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i + 1 < items.size(); i++) {
            if (!isInstr(items.get(i)) || !isInstr(items.get(i + 1))) continue;
            Opcode op = getOp(items.get(i));
            if ((op == Opcode.CONST || op == Opcode.LVAR || op == Opcode.GVAR)
                    && getOp(items.get(i + 1)) == Opcode.POP) {
                items.remove(i + 1);
                items.remove(i);
                i--;
                changed = true;
            }
        }
        return changed;
    }

    // Pass D: Replace JUMP L with RETURN when L leads to RETURN
    private static boolean peepholeJumpToReturn(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i < items.size(); i++) {
            if (!isInstr(items.get(i)) || getOp(items.get(i)) != Opcode.JUMP) continue;
            String target = getTarget(items.get(i));
            int labelIdx = -1;
            for (int j = 0; j < items.size(); j++) {
                if (isLabel(items.get(j)) && items.get(j).equals(target)) { labelIdx = j; break; }
            }
            if (labelIdx < 0) continue;
            int k = labelIdx + 1;
            while (k < items.size() && isLabel(items.get(k))) k++;
            if (k < items.size() && isInstr(items.get(k)) && getOp(items.get(k)) == Opcode.RETURN) {
                items.set(i, Pair.list((Object) Opcode.RETURN));
                changed = true;
            }
        }
        return changed;
    }

    // Pass E: Replace NOT + FJUMP/TJUMP with flipped branch
    private static boolean peepholeNotBranch(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i + 1 < items.size(); i++) {
            if (!isInstr(items.get(i)) || !isInstr(items.get(i + 1))) continue;
            if (getOp(items.get(i)) != Opcode.NOT) continue;
            Opcode next = getOp(items.get(i + 1));
            if (next == Opcode.FJUMP) {
                String label = getTarget(items.get(i + 1));
                items.set(i, Pair.list((Object) Opcode.TJUMP, label));
                items.remove(i + 1);
                changed = true;
            } else if (next == Opcode.TJUMP) {
                String label = getTarget(items.get(i + 1));
                items.set(i, Pair.list((Object) Opcode.FJUMP, label));
                items.remove(i + 1);
                changed = true;
            }
        }
        return changed;
    }

    // Pass F: Fold CONST + FJUMP/TJUMP into JUMP or remove both
    private static boolean peepholeConstBranch(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i + 1 < items.size(); i++) {
            if (!isInstr(items.get(i)) || !isInstr(items.get(i + 1))) continue;
            if (getOp(items.get(i)) != Opcode.CONST) continue;
            Opcode next = getOp(items.get(i + 1));
            if (next != Opcode.FJUMP && next != Opcode.TJUMP) continue;
            Object constVal = Value.asPair(items.get(i)).second();
            String label = getTarget(items.get(i + 1));
            boolean isFalse = constVal.equals(Value.F);
            boolean branchTaken = (next == Opcode.FJUMP) ? isFalse : !isFalse;
            if (branchTaken) {
                // Always taken: replace both with JUMP
                items.set(i, Pair.list((Object) Opcode.JUMP, label));
                items.remove(i + 1);
            } else {
                // Never taken: remove both (net stack effect 0)
                items.remove(i + 1);
                items.remove(i);
                i--;
            }
            changed = true;
        }
        return changed;
    }

    // Pass G: Thread jumps through intermediate unconditional jumps
    private static boolean peepholeJumpThread(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i < items.size(); i++) {
            if (!isInstr(items.get(i))) continue;
            Opcode op = getOp(items.get(i));
            if (op != Opcode.JUMP && op != Opcode.FJUMP && op != Opcode.TJUMP && op != Opcode.TJUMP_KEEP) continue;
            String target = getTarget(items.get(i));
            // Follow the chain up to 5 hops
            Set<String> visited = new HashSet<>();
            visited.add(target);
            String current = target;
            for (int depth = 0; depth < 5; depth++) {
                int labelIdx = -1;
                for (int j = 0; j < items.size(); j++) {
                    if (isLabel(items.get(j)) && items.get(j).equals(current)) { labelIdx = j; break; }
                }
                if (labelIdx < 0) break;
                int k = labelIdx + 1;
                while (k < items.size() && isLabel(items.get(k))) k++;
                if (k >= items.size() || !isInstr(items.get(k)) || getOp(items.get(k)) != Opcode.JUMP) break;
                String next = getTarget(items.get(k));
                if (visited.contains(next)) break;
                visited.add(next);
                current = next;
            }
            if (!current.equals(target)) {
                items.set(i, Pair.list((Object) op, current));
                changed = true;
            }
        }
        return changed;
    }

    // Pass H: Remove labels not referenced by any jump or save
    private static boolean peepholeUnusedLabels(List<Object> items) {
        Set<String> referenced = new HashSet<>();
        for (Object item : items) {
            if (!isInstr(item)) continue;
            Opcode op = getOp(item);
            if (op == Opcode.JUMP || op == Opcode.FJUMP || op == Opcode.TJUMP || op == Opcode.SAVE
                || op == Opcode.TJUMP_KEEP) {
                referenced.add(getTarget(item));
            } else if (op == Opcode.LOOP) {
                referenced.add((String) Value.asPair(item).fourth());
            }
        }
        boolean changed = false;
        for (int i = items.size() - 1; i >= 0; i--) {
            if (isLabel(items.get(i)) && !referenced.contains((String) items.get(i))) {
                items.remove(i);
                changed = true;
            }
        }
        return changed;
    }

    // Pass K: a TJUMP_KEEP to a branch on the kept value branches itself:
    // to L: FJUMP M or L: POP -> TJUMP past it; to L: TJUMP/TJUMP_KEEP M -> that
    private boolean peepholeKeepBranch(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i < items.size(); i++) {
            if (!isInstr(items.get(i)) || getOp(items.get(i)) != Opcode.TJUMP_KEEP) continue;
            String target = getTarget(items.get(i));
            int labelIdx = -1;
            for (int j = 0; j < items.size(); j++) {
                if (isLabel(items.get(j)) && items.get(j).equals(target)) { labelIdx = j; break; }
            }
            if (labelIdx < 0) continue;
            int k = labelIdx + 1;
            while (k < items.size() && isLabel(items.get(k))) k++;
            if (k >= items.size() || !isInstr(items.get(k))) continue;
            Opcode next = getOp(items.get(k));
            if (next == Opcode.TJUMP || next == Opcode.TJUMP_KEEP) {
                items.set(i, Pair.list((Object) next, getTarget(items.get(k))));
                changed = true;
            } else if ((next == Opcode.FJUMP || next == Opcode.POP) && k > i) {
                String after;
                if (k + 1 < items.size() && isLabel(items.get(k + 1))) {
                    after = (String) items.get(k + 1);
                } else {
                    after = genLabel();
                    items.add(k + 1, after);
                }
                items.set(i, Pair.list((Object) Opcode.TJUMP, after));
                changed = true;
            }
        }
        return changed;
    }

    // Pass I: Fuse LVAR + CONST(long) + ADD/SUB 2 -> LVAR_ADD_IMM / LVAR_SUB_IMM
    private static boolean peepholeLocalAddImm(List<Object> items) {
        boolean changed = false;
        for (int i = 0; i + 2 < items.size(); i++) {
            if (!isInstr(items.get(i)) || !isInstr(items.get(i + 1)) || !isInstr(items.get(i + 2))) continue;
            if (getOp(items.get(i)) != Opcode.LVAR) continue;
            Pair constInstr = Value.asPair(items.get(i + 1));
            if (getOp(constInstr) != Opcode.CONST) continue;
            if (!(constInstr.second() instanceof Long)) continue;
            long imm = (long)(Long) constInstr.second();
            Pair arithInstr = Value.asPair(items.get(i + 2));
            Opcode arithOp = getOp(arithInstr);
            if (arithOp != Opcode.ADD && arithOp != Opcode.SUB) continue;
            if ((int) arithInstr.second() != 2) continue;
            Pair lvarInstr = Value.asPair(items.get(i));
            long packed = ((long)(int) lvarInstr.second() << 16) | (long)(int) lvarInstr.third();
            Opcode fused = arithOp == Opcode.ADD ? Opcode.LVAR_ADD_IMM : Opcode.LVAR_SUB_IMM;
            items.set(i, Pair.list2(fused, packed, imm).withPos(lvarInstr.pos));
            items.remove(i + 2);
            items.remove(i + 1);
            changed = true;
        }
        return changed;
    }

    // Pass J: Fuse frequent instruction sequences into one instruction.
    // Runs once after the other passes, which do not know the fused
    // opcodes (the jump passes would miss their targets).
    private static void peepholeFuse(List<Object> items) {
        for (int i = 0; i + 1 < items.size(); i++) {
            if (!isInstr(items.get(i)) || !isInstr(items.get(i + 1))) continue;
            Pair a = Value.asPair(items.get(i));
            Pair b = Value.asPair(items.get(i + 1));
            Pair c = i + 2 < items.size() && isInstr(items.get(i + 2)) ? Value.asPair(items.get(i + 2)) : null;
            Opcode opA = getOp(a), opB = getOp(b), opC = c != null ? getOp(c) : null;
            Pair fused = null;
            int length = 2;
            if (opA == Opcode.GVAR && (opB == Opcode.CALLS || opB == Opcode.CALLJ)) {
                // arg count, module, symbol
                fused = Pair.list2(opB == Opcode.CALLS ? Opcode.GCALLS : Opcode.GCALLJ,
                                   b.second(), a.third(), a.second()).withPos(b.pos);
            } else if (opA == Opcode.LVAR && (opB == Opcode.CAR || opB == Opcode.CDR)) {
                fused = Pair.list2(opB == Opcode.CAR ? Opcode.LVAR_CAR : Opcode.LVAR_CDR,
                                   a.second(), a.third()).withPos(b.pos);
            } else if (opA == Opcode.LVAR && opB == Opcode.CONST && opC == Opcode.VECTOR_REF
                       && b.second() instanceof Long
                       && (long) (Long) b.second() >= 0 && (long) (Long) b.second() <= Integer.MAX_VALUE) {
                fused = Pair.list2(Opcode.LVAR_VREF, a.second(), a.third(),
                                   (int) (long) (Long) b.second()).withPos(c.pos);
                length = 3;
            } else if (opA == Opcode.LVAR && (opB == Opcode.IS_NULL || opB == Opcode.IS_PAIR)
                       && opC == Opcode.FJUMP) {
                fused = Pair.list2(opB == Opcode.IS_NULL ? Opcode.LVAR_NULL_FJUMP : Opcode.LVAR_PAIR_FJUMP,
                                   a.second(), a.third(), c.second()).withPos(c.pos);
                length = 3;
            } else if (opA == Opcode.CONST && opB == Opcode.EQ_P && opC == Opcode.FJUMP) {
                fused = Pair.list2(Opcode.CONST_EQ_FJUMP, a.second(), c.second()).withPos(c.pos);
                length = 3;
            }
            if (fused == null) continue;
            items.set(i, fused);
            for (int k = 1; k < length; k++) items.remove(i + 1);
        }
    }

    private Pair assemble(Pair fn) {
        Object code = fn.sixth();
        Map<String, Integer> labels = new HashMap<>();
        List<Instruction> instructions = new CodeList();
        int i = 0;
        while (code != Value.NIL) {
            if (Value.isSymbol(Value.asPair(code).car)) {
                labels.put(Value.asSymbol(Value.asPair(code).car), i);
            } else {
                Pair current = Value.asPair(Value.asPair(code).car);
                Instruction instr = new Instruction();
                instr.opcode = (Opcode) current.first();
                if (current.length() > 1) instr.arg1 = current.second();
                if (current.length() > 2) instr.arg2 = current.third();
                if (current.length() > 3 && Instruction.hasArg3(instr.opcode)) instr.arg3 = current.fourth();
                if (current.pos != null) instr.pos = current.pos;
                instructions.add(instr);
                i++;
            }
            code = Value.asPair(code).cdr;
        }
        for (Instruction instruction : instructions) {
            if (instruction.opcode == Opcode.JUMP ||
                    instruction.opcode == Opcode.TJUMP ||
                    instruction.opcode == Opcode.TJUMP_KEEP ||
                    instruction.opcode == Opcode.FJUMP ||
                    instruction.opcode == Opcode.SAVE) {
                instruction.arg1 = labels.get(instruction.arg1);
            } else if (instruction.opcode == Opcode.CONST_EQ_FJUMP) {
                instruction.arg2 = labels.get(instruction.arg2);
            } else if (instruction.opcode == Opcode.LVAR_NULL_FJUMP ||
                    instruction.opcode == Opcode.LVAR_PAIR_FJUMP ||
                    instruction.opcode == Opcode.LOOP) {
                instruction.arg3 = labels.get(instruction.arg3);
            }
            instruction.decodeInts();
        }
        Value.asPair(fn.nthCdr(5)).car = instructions;
        return fn;
    }

    public Pair compile(SourcePos pos, Object x) {
        labelNum = 1;
        Expander expander = new Expander(modules);
        x = expander.expand(pos, x);
        return compLambda(pos, Value.NIL, Pair.list(x), (Object) Value.NIL);
    }
}
