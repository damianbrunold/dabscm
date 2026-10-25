package scheme.jit;

import java.util.Arrays;

import scheme.*;
import scheme.primitives.PrimitiveEqP;
import scheme.primitives.PrimitiveEqvP;

// Runtime support called by compiled code (Jit). The operations mirror the
// corresponding cases of VM.run.
public final class Rt {
    private Rt() {}

    // ---- calls ----

    public static Object trampoline(VM vm, Object r, int depth) {
        while (r instanceof TailCall) {
            TailCall tc = (TailCall) r;
            Lambda lam = tc.fn;
            JitCode jit = lam.cl.jit;
            r = jit != null ? jit.call(vm, lam, tc.frame, depth + 1)
                            : vm.executeNested(lam, tc.frame, depth + 1);
        }
        return r;
    }

    public static Object interp(VM vm, Lambda lam, Object[] frame, int depth) {
        return vm.executeNested(lam, frame, depth + 1);
    }

    public static Object tailCall(Lambda lam, Object[] frame) {
        if (Jit.stats) Jit.statTailCalls++;
        return new TailCall(lam, frame);
    }

    // f applied to frame[1..] when f is not a lambda.
    public static Object prim(VM vm, Object f, Object[] frame, Instruction ins) {
        if (!(f instanceof Primitive))
            throw new SchemeError(ins.pos, f + " is not a function, cannot apply");
        Primitive prim = (Primitive) f;
        int n = frame.length - 1;
        Object[] args = new Object[n];
        for (int i = 0; i < n; i++) args[i] = VM.primaryValue(frame[i + 1]);
        try {
            return prim.apply(ins.pos, args);
        } catch (SchemeError | FrameCapture | ContinuationJump e) {
            throw e;
        } catch (ClassCastException e) {
            throw VM.wrongArgumentTypeError(ins.pos, prim.name(), e);
        } catch (RuntimeException e) {
            throw new SchemeError(ins.pos, "Failed in " + prim.name() + ": " + e.getMessage());
        }
    }

    // calls for compact code (Jit.Translator.compact): f applied to frame
    public static Object call(VM vm, int depth, Object f, Object[] frame, Instruction ins) {
        if (f instanceof Lambda) {
            Lambda lam = (Lambda) f;
            JitCode jit = lam.cl.jit;
            Object r = jit != null && depth < Jit.maxDepth ? jit.call(vm, lam, frame, depth + 1)
                                                          : vm.executeNested(lam, frame, depth + 1);
            return r instanceof TailCall ? trampoline(vm, r, depth) : r;
        }
        return prim(vm, f, frame, ins);
    }

    public static Object tail(VM vm, int depth, Object f, Object[] frame, Instruction ins) {
        if (f instanceof Lambda) {
            Lambda lam = (Lambda) f;
            if (depth >= Jit.tailDepth) return tailCall(lam, frame);
            JitCode jit = lam.cl.jit;
            return jit != null ? jit.call(vm, lam, frame, depth + 1) : vm.executeNested(lam, frame, depth + 1);
        }
        return prim(vm, f, frame, ins);
    }

    public static Object call0(VM vm, int depth, Object f, Instruction ins) {
        return call(vm, depth, f, new Object[1], ins);
    }
    public static Object call1(VM vm, int depth, Object f, Instruction ins, Object a) {
        return call(vm, depth, f, new Object[] { null, a }, ins);
    }
    public static Object call2(VM vm, int depth, Object f, Instruction ins, Object a, Object b) {
        return call(vm, depth, f, new Object[] { null, a, b }, ins);
    }
    public static Object call3(VM vm, int depth, Object f, Instruction ins, Object a, Object b, Object c) {
        return call(vm, depth, f, new Object[] { null, a, b, c }, ins);
    }
    public static Object call4(VM vm, int depth, Object f, Instruction ins, Object a, Object b, Object c, Object d) {
        return call(vm, depth, f, new Object[] { null, a, b, c, d }, ins);
    }
    public static Object callN(VM vm, int depth, Object f, Instruction ins, Object[] frame) {
        return call(vm, depth, f, frame, ins);
    }
    public static Object tail0(VM vm, int depth, Object f, Instruction ins) {
        return tail(vm, depth, f, new Object[1], ins);
    }
    public static Object tail1(VM vm, int depth, Object f, Instruction ins, Object a) {
        return tail(vm, depth, f, new Object[] { null, a }, ins);
    }
    public static Object tail2(VM vm, int depth, Object f, Instruction ins, Object a, Object b) {
        return tail(vm, depth, f, new Object[] { null, a, b }, ins);
    }
    public static Object tail3(VM vm, int depth, Object f, Instruction ins, Object a, Object b, Object c) {
        return tail(vm, depth, f, new Object[] { null, a, b, c }, ins);
    }
    public static Object tail4(VM vm, int depth, Object f, Instruction ins, Object a, Object b, Object c, Object d) {
        return tail(vm, depth, f, new Object[] { null, a, b, c, d }, ins);
    }
    public static Object tailN(VM vm, int depth, Object f, Instruction ins, Object[] frame) {
        return tail(vm, depth, f, frame, ins);
    }

    public static Object gcall0(VM vm, int depth, Instruction ins) {
        return call(vm, depth, gvarCall(vm, ins), new Object[1], ins);
    }
    public static Object gcall1(VM vm, int depth, Instruction ins, Object a) {
        return call(vm, depth, gvarCall(vm, ins), new Object[] { null, a }, ins);
    }
    public static Object gcall2(VM vm, int depth, Instruction ins, Object a, Object b) {
        return call(vm, depth, gvarCall(vm, ins), new Object[] { null, a, b }, ins);
    }
    public static Object gcall3(VM vm, int depth, Instruction ins, Object a, Object b, Object c) {
        return call(vm, depth, gvarCall(vm, ins), new Object[] { null, a, b, c }, ins);
    }
    public static Object gcall4(VM vm, int depth, Instruction ins, Object a, Object b, Object c, Object d) {
        return call(vm, depth, gvarCall(vm, ins), new Object[] { null, a, b, c, d }, ins);
    }
    public static Object gcallN(VM vm, int depth, Instruction ins, Object[] frame) {
        return call(vm, depth, gvarCall(vm, ins), frame, ins);
    }

    // An exception of primitive f called by compiled code at ins (Rt.prim).
    public static RuntimeException primError(RuntimeException e, Object f, Instruction ins) {
        if (e instanceof SchemeError || e instanceof FrameCapture || e instanceof ContinuationJump) return e;
        Primitive prim = (Primitive) f;
        if (e instanceof ClassCastException) return VM.wrongArgumentTypeError(ins.pos, prim.name(), (ClassCastException) e);
        return new SchemeError(ins.pos, "Failed in " + prim.name() + ": " + e.getMessage());
    }

    public static SchemeError arity(Lambda self, Instruction ins, int nargs) {
        return VM.arityError(self, ins, nargs, "");
    }

    // ARGSDOT: the frame of the fixed arguments and the rest list.
    public static Object[] argsDot(Lambda self, Instruction ins, Object[] frame) {
        int fixed = ins.i1, nargs = frame.length - 1;
        if (nargs < fixed) throw VM.arityError(self, ins, nargs, " or more");
        Object rest = Value.NIL;
        for (int i = nargs; i > fixed; i--) rest = new Pair(frame[i], rest);
        Object[] f = new Object[fixed + 2];
        f[0] = self.env;
        System.arraycopy(frame, 1, f, 1, fixed);
        f[fixed + 1] = rest;
        return f;
    }

    public static Lambda makeLambda(Object env, java.util.List<Instruction> code, String doc) {
        Lambda lambda = new Lambda(env, code);
        if (doc != null) lambda.doc = doc;
        return lambda;
    }

    public static void checkTerm(VM vm) {
        SchemeThread t = vm.thread;
        if (t != null && t.terminated) throw new SchemeError("thread terminated");
    }

    // ---- variables ----

    public static Object pv(Object v) {
        return VM.primaryValue(v);
    }

    public static Object gvar(VM vm, Instruction ins) {
        Cell cell = ins.jitCell;
        if (cell != null && ins.jitCellGeneration == Modules.generation) return cell.value;
        return resolve(vm, ins, ins.arg1).value;
    }

    // the global called by GCALLS/GCALLJ
    public static Object gvarCall(VM vm, Instruction ins) {
        Cell cell = ins.jitCell;
        if (cell != null && ins.jitCellGeneration == Modules.generation) return cell.value;
        return resolve(vm, ins, ins.arg3).value;
    }

    private static Cell resolve(VM vm, Instruction ins, Object symbol) {
        int generation = Modules.generation;
        Cell cell = vm.globalCell(ins, symbol, (String) ins.arg2);
        ins.jitCell = cell;
        ins.jitCellGeneration = generation;
        return cell;
    }

    public static void gset(VM vm, Instruction ins, Object v) {
        Object value = VM.primaryValue(v);
        Cell cell = ins.cachedCell;
        if (cell != null && ins.cachedCellGeneration == vm.modules.cacheGeneration && !Scheme.strictImports) {
            cell.value = value;
            if (value instanceof Lambda) ((Lambda) value).name = ins.arg1.toString();
            return;
        }
        vm.globalSet(ins, value);
    }

    // ---- intrinsics ----

    public static Object bool(boolean b) { return b ? Value.T : Value.F; }

    public static Object isNull(Object v) { return v == Value.NIL ? Value.T : Value.F; }

    public static Object isPair(Object v) { return Value.isPair(v) ? Value.T : Value.F; }

    public static boolean isFalse(Object v) { return v.equals(Value.F); }

    public static Object not(Object v) { return v.equals(Value.F) ? Value.T : Value.F; }

    public static Object eq(Object a, Object b) { return PrimitiveEqP.eq(a, b) ? Value.T : Value.F; }

    public static Object eqv(Object a, Object b) { return PrimitiveEqvP.eqv(a, b) ? Value.T : Value.F; }

    public static Object add(Object ia, Object ib) {
        if (ia instanceof Long && ib instanceof Long) {
            long a = (Long) ia, b = (Long) ib, r = a + b;
            if (((a ^ r) & (b ^ r)) >= 0) return r;
        }
        return VM.add2(ia, ib);
    }

    public static Object sub(Object ia, Object ib) {
        if (ia instanceof Long && ib instanceof Long) {
            long a = (Long) ia, b = (Long) ib, r = a - b;
            if (((a ^ b) & (a ^ r)) >= 0) return r;
        }
        return VM.sub2(ia, ib);
    }

    public static Object mul(Object ia, Object ib) {
        if (ia instanceof Long && ib instanceof Long) {
            long a = (Long) ia, b = (Long) ib, r = a * b, high = Math.multiplyHigh(a, b);
            if ((high == 0 && r >= 0) || (high == -1 && r < 0)) return r;
        }
        return VM.mul2(ia, ib);
    }

    public static Object div(Object ia, Object ib, Instruction ins) {
        return VM.div2(ins.pos, ia, ib);
    }

    public static Object negate(Object ia) {
        return VM.negate(ia);
    }

    public static Object addImm(Object v, long imm) {
        if (v instanceof Long) {
            long a = (Long) v, r = a + imm;
            if (((a ^ r) & (imm ^ r)) >= 0) return r;
        }
        return VM.add2(v, imm);
    }

    public static Object subImm(Object v, long imm) {
        if (v instanceof Long) {
            long a = (Long) v, r = a - imm;
            if (((a ^ imm) & (a ^ r)) >= 0) return r;
        }
        return VM.sub2(v, imm);
    }

    public static boolean numEqZ(Object ia, Object ib, Instruction ins) {
        return ia instanceof Long && ib instanceof Long ? (long) (Long) ia == (long) (Long) ib
            : VM.compare2(Opcode.NUM_EQ, ins.pos, ia, ib);
    }

    public static boolean numLtZ(Object ia, Object ib, Instruction ins) {
        return ia instanceof Long && ib instanceof Long ? (long) (Long) ia < (long) (Long) ib
            : VM.compare2(Opcode.NUM_LT, ins.pos, ia, ib);
    }

    public static boolean numGtZ(Object ia, Object ib, Instruction ins) {
        return ia instanceof Long && ib instanceof Long ? (long) (Long) ia > (long) (Long) ib
            : VM.compare2(Opcode.NUM_GT, ins.pos, ia, ib);
    }

    public static boolean numLteZ(Object ia, Object ib, Instruction ins) {
        return ia instanceof Long && ib instanceof Long ? (long) (Long) ia <= (long) (Long) ib
            : VM.compare2(Opcode.NUM_LTE, ins.pos, ia, ib);
    }

    public static boolean numGteZ(Object ia, Object ib, Instruction ins) {
        return ia instanceof Long && ib instanceof Long ? (long) (Long) ia >= (long) (Long) ib
            : VM.compare2(Opcode.NUM_GTE, ins.pos, ia, ib);
    }

    public static Object numEq(Object a, Object b, Instruction ins) { return numEqZ(a, b, ins) ? Value.T : Value.F; }
    public static Object numLt(Object a, Object b, Instruction ins) { return numLtZ(a, b, ins) ? Value.T : Value.F; }
    public static Object numGt(Object a, Object b, Instruction ins) { return numGtZ(a, b, ins) ? Value.T : Value.F; }
    public static Object numLte(Object a, Object b, Instruction ins) { return numLteZ(a, b, ins) ? Value.T : Value.F; }
    public static Object numGte(Object a, Object b, Instruction ins) { return numGteZ(a, b, ins) ? Value.T : Value.F; }

    // An arithmetic intrinsic with other than the inlined argument count.
    public static Object nary(Object[] args, Instruction ins) {
        Primitive prim;
        switch (ins.opcode) {
            case ADD: prim = VM.S_ADD; break;
            case SUB: prim = VM.S_SUB; break;
            case MUL: prim = VM.S_MUL; break;
            case DIV: prim = VM.S_DIV; break;
            case NUM_EQ: prim = VM.S_NUM_EQ; break;
            case NUM_LT: prim = VM.S_NUM_LT; break;
            case NUM_GT: prim = VM.S_NUM_GT; break;
            case NUM_LTE: prim = VM.S_NUM_LTE; break;
            default: prim = VM.S_NUM_GTE; break;
        }
        return prim.apply(ins.pos, args);
    }

    public static Object vectorRef(Object v, Object idx, Instruction ins) {
        Object[] vec = Value.asVector(v);
        int i = IntegerMath.toInt(idx);
        if (i < 0 || i >= vec.length)
            throw new SchemeError(ins.pos, "vector-ref: index out of range: ~a", idx);
        return vec[i];
    }

    public static Object vrefConst(Object v, int i, Instruction ins) {
        Object[] vec = Value.asVector(v);
        if (i >= vec.length)
            throw new SchemeError(ins.pos, "vector-ref: index out of range: ~a", (long) i);
        return vec[i];
    }

    public static Object vectorSet(Object v, Object idx, Object val, Instruction ins) {
        Object[] vec = Value.asVector(v);
        int i = IntegerMath.toInt(idx);
        if (i < 0 || i >= vec.length)
            throw new SchemeError(ins.pos, "vector-set!: index out of range: ~a", idx);
        vec[i] = val;
        return new Values();
    }

    public static Object cxr(Object v, int path) {
        for (int p = path; p != 1; p >>>= 1)
            v = (p & 1) != 0 ? Value.asPair(v).cdr : Value.asPair(v).car;
        return v;
    }

    // ---- unwinding ----

    // An exception t in compiled self at instruction ip, with the frame's
    // environment and operand stack: returns what to throw on. A capture
    // from a callee gets this frame's part of the stack added (none for a
    // tail call); an error raised here calls the innermost exception
    // handler in place or, with none, unwinds to the root.
    public static Throwable unwind(Throwable t, VM vm, Lambda self, int ip, Object env, Object[] slots, int depth) {
        if (t instanceof ContinuationJump) return t;
        Instruction ins = self.codeArr[ip];
        int d = self.cl.depths[ip];
        if (t instanceof FrameCapture) {
            FrameCapture fc = (FrameCapture) t;
            if (ins.opcode == Opcode.CALLS || ins.opcode == Opcode.GCALLS) {
                int below = d - ins.i1 - (ins.opcode == Opcode.CALLS ? 1 : 0);
                Object[] seg = Arrays.copyOf(slots, below + 1);
                seg[below] = new ReturnAddress(ip + 1, self, env);
                fc.add(seg, null);
            }
            return fc;
        }
        SchemeError err;
        if (t instanceof SchemeError) err = (SchemeError) t;
        else if (t instanceof ClassCastException) err = VM.castError(self, ip + 1, (ClassCastException) t);
        else return t;
        Object[] stack = Arrays.copyOf(slots, d);
        if (vm.exceptionHandlers != Value.NIL) return raiseInPlace(vm, err, stack, depth);
        if (Jit.stats) Jit.statErrors++;
        FrameCapture fc = new FrameCapture(err, self, ip + 1, env, 0);
        fc.add(stack, null);
        return fc;
    }

    // VM.setupRaiseCall for compiled code: the handlers are called on top
    // of the raising frame, whose operand stack is stack.
    private static Throwable raiseInPlace(VM vm, SchemeError err, Object[] stack, int depth) {
        Object condition = err.errorObject != null ? err.errorObject
            : new ErrorObject(err.getMessage(), new Object[0]);
        for (;;) {
            Pair hl = Value.asPair(vm.exceptionHandlers);
            Object handler = hl.car;
            vm.exceptionHandlers = hl.cdr;
            ErrorObject returned;
            if (handler instanceof Lambda) {
                Lambda lam = (Lambda) handler;
                Object[] frame = new Object[] { null, condition };
                try {
                    JitCode jit = lam.cl.jit;
                    if (jit != null) trampoline(vm, jit.call(vm, lam, frame, depth + 1), depth);
                    else vm.executeNested(lam, frame, depth + 1);
                } catch (FrameCapture fc) {
                    Object[] seg = Arrays.copyOf(stack, stack.length + 1);
                    seg[stack.length] = new ReturnAddress(0, vm.raiseReturnedLambda, Value.NIL);
                    fc.add(seg, null);
                    return fc;
                }
                returned = new ErrorObject("raise: exception handler returned", new Object[0]);
            } else if (handler instanceof Primitive) {
                try {
                    ((Primitive) handler).apply(null, new Object[] { condition });
                    returned = new ErrorObject("raise: exception handler returned", new Object[] { condition });
                } catch (SchemeError inner) {
                    returned = null;
                    condition = inner.errorObject != null ? inner.errorObject
                        : new ErrorObject(inner.getMessage(), new Object[0]);
                    if (vm.exceptionHandlers == Value.NIL) return fatal(vm, inner, stack);
                }
            } else {
                return fatal(vm, new SchemeError((SourcePos) null,
                    "with-exception-handler: handler is not a procedure"), stack);
            }
            if (returned != null) {
                if (vm.exceptionHandlers == Value.NIL)
                    return fatal(vm, new SchemeError((SourcePos) null, returned), stack);
                condition = returned;
            }
        }
    }

    private static FrameCapture fatal(VM vm, SchemeError e, Object[] stack) {
        FrameCapture fc = new FrameCapture(e, vm.raiseReturnedLambda, 1, Value.NIL, 0);
        fc.add(stack, null);
        return fc;
    }
}
