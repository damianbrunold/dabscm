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
}
