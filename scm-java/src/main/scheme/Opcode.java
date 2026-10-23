package scheme;

public enum Opcode
{
    LVAR,
    LSET,
    GVAR,
    GSET,
    POP,
    CONST,
    JUMP,
    FJUMP,
    TJUMP,
    SAVE,
    RETURN,
    CALLJ,
    ARGS,
    ARGSDOT,
    ARGMV,
    FN,
    SETCC,
    CC,
    FLATTEN_APPLY,
    FLATTEN_MULTVALS,
    HANDLER_RETURNED,
    // Intrinsics: inline primitive ops — no SAVE/array/dispatch overhead
    CAR, CDR, CONS, IS_NULL, IS_PAIR, NOT,
    ADD, SUB, MUL, DIV,
    NUM_EQ, NUM_LT, NUM_GT, NUM_LTE, NUM_GTE,
    EQ_P, EQV_P,
    VECTOR_REF, VECTOR_SET,
    LVAR_ADD_IMM, LVAR_SUB_IMM,
    EXTEND,
    // non-tail call without SAVE: (args... f CALLS n)
    CALLS,
    // drops the innermost frame at the end of a non-tail let body
    POPENV,
    // fused instruction sequences (Compiler.peepholeFuse)
    GCALLS, GCALLJ,                           // GVAR + CALLS/CALLJ
    LVAR_CAR, LVAR_CDR,                       // LVAR + CAR/CDR
    LVAR_VREF,                                // LVAR + CONST k + VECTOR_REF
    LVAR_NULL_FJUMP, LVAR_PAIR_FJUMP,         // LVAR + IS_NULL/IS_PAIR + FJUMP
    CONST_EQ_FJUMP,                           // CONST + EQ_P + FJUMP
    // (c[ad]+r x): path bits + name (Compiler.cxrPath); (list a ...): n
    CXR, LIST,
}
