namespace scheme;

// c[ad]{2,4}r beyond the hand-written caar/cadr/cadar: one class, the
// accessor path decoded from the name (see Compiler.CxrPath).
public class PrimitiveCxr : Primitive
{
    public static readonly string[] Names =
    {
        "cdar", "cddr", "caaar", "caadr", "caddr", "cdaar", "cdadr", "cddar", "cdddr", "caaaar", "caaadr", "caadar", "caaddr", "cadaar", "cadadr", "caddar", "cadddr", "cdaaar", "cdaadr", "cdadar", "cdaddr", "cddaar", "cddadr", "cdddar", "cddddr"
    };

    private readonly string name;
    private readonly int path;

    public PrimitiveCxr(string name)
    {
        this.name = name;
        path = Compiler.CxrPath(name);
    }

    public override string Name()
    {
        return name;
    }

    public override string Info() => name switch
    {
        "cdar" =>
            "Syntax: (cdar pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).\n" +
            "Example:\n" +
            "  (cdar '((1 2) 3)) => (2)",
        "cddr" =>
            "Syntax: (cddr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the cdr of the cdr of pair. Equivalent to (cdr (cdr pair)).\n" +
            "Example:\n" +
            "  (cddr '(1 2 3)) => (3)",
        "caaar" =>
            "Syntax: (caaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car pair))). Accesses the car of the\n" +
            "car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaar '(((1 2) 3) 4)) => 1",
        "caadr" =>
            "Syntax: (caadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr pair))). Accesses the car of the\n" +
            "car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (caadr '(1 (2 3) 4)) => 2",
        "caddr" =>
            "Syntax: (caddr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the car of the cdr of the cdr of pair. Equivalent to (car (cdr (cdr pair))). This is the third element of a list.\n" +
            "Example:\n" +
            "  (caddr '(1 2 3)) => 3",
        "cdaar" =>
            "Syntax: (cdaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car pair))). Accesses the cdr of the\n" +
            "car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaar '(((1 2) 3) 4)) => (2)",
        "cdadr" =>
            "Syntax: (cdadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr pair))). Accesses the cdr of the\n" +
            "car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdadr '(1 (2 3) 4)) => (3)",
        "cddar" =>
            "Syntax: (cddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car pair))). Accesses the cdr of the\n" +
            "cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddar '((1 2 3) 4)) => (3)",
        "cdddr" =>
            "Syntax: (cdddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr pair))). Returns the tail of a\n" +
            "list starting after the third element.\n" +
            "Example:\n" +
            "  (cdddr '(1 2 3 4 5)) => (4 5)",
        "caaaar" =>
            "Syntax: (caaaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car (car pair)))). Accesses the car of\n" +
            "four nested car operations on a pair structure.\n" +
            "Example:\n" +
            "  (caaaar '((((1 2) 3) 4) 5)) => 1",
        "caaadr" =>
            "Syntax: (caaadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car (cdr pair)))). Accesses the car of\n" +
            "the car of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaadr '(1 ((2 3) 4) 5)) => 2",
        "caadar" =>
            "Syntax: (caadar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr (car pair)))). Accesses the car of\n" +
            "the car of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caadar '((1 (2 3)) 4)) => 2",
        "caaddr" =>
            "Syntax: (caaddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr (cdr pair)))). Accesses the car of\n" +
            "the car of the third tail of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaddr '(1 2 (3 4) 5)) => 3",
        "cadaar" =>
            "Syntax: (cadaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (car (car pair)))). Accesses the car of\n" +
            "the cdr of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cadaar '(((1 2) 3) 4)) => 2",
        "cadadr" =>
            "Syntax: (cadadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (car (cdr pair)))). Accesses the car of\n" +
            "the cdr of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cadadr '(1 (2 3) 4)) => 3",
        "caddar" =>
            "Syntax: (caddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (cdr (car pair)))). Accesses the car of\n" +
            "the cdr of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caddar '((1 2 3) 4)) => 3",
        "cadddr" =>
            "Syntax: (cadddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (cdr (cdr pair)))). Returns the fourth\n" +
            "element of a list.\n" +
            "Example:\n" +
            "  (cadddr '(1 2 3 4 5)) => 4",
        "cdaaar" =>
            "Syntax: (cdaaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car (car pair)))). Accesses the cdr of\n" +
            "the car of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaaar '((((1 2) 3) 4) 5)) => (2)",
        "cdaadr" =>
            "Syntax: (cdaadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car (cdr pair)))). Accesses the cdr of\n" +
            "the car of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaadr '(1 ((2 3) 4) 5)) => (3)",
        "cdadar" =>
            "Syntax: (cdadar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr (car pair)))). Accesses the cdr of\n" +
            "the car of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdadar '((1 (2 3)) 4)) => (3)",
        "cdaddr" =>
            "Syntax: (cdaddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr (cdr pair)))). Accesses the cdr of\n" +
            "the car of the third tail of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaddr '(1 2 (3 4) 5)) => (4)",
        "cddaar" =>
            "Syntax: (cddaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car (car pair)))). Accesses the cdr of\n" +
            "the cdr of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddaar '(((1 2 3) 4) 5)) => (3)",
        "cddadr" =>
            "Syntax: (cddadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car (cdr pair)))). Accesses the cdr of\n" +
            "the cdr of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddadr '(1 (2 3 4) 5)) => (4)",
        "cdddar" =>
            "Syntax: (cdddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr (car pair)))). Accesses the cdr of\n" +
            "the cdr of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdddar '((1 2 3 4) 5)) => (4)",
        "cddddr" =>
            "Syntax: (cddddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr (cdr pair)))). Returns the tail of\n" +
            "a list starting after the fourth element.\n" +
            "Example:\n" +
            "  (cddddr '(1 2 3 4 5 6)) => (5 6)",
        _ => "",
    };

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        object v = arguments[0];
        for (int p = path; p != 1; p >>= 1)
            v = (p & 1) != 0 ? Value.AsPair(v).cdr : Value.AsPair(v).car;
        return v;
    }
}
