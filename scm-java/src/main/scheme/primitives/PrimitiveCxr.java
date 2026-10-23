package scheme.primitives;

import scheme.*;

// c[ad]{2,4}r beyond the hand-written caar/cadr/cadar: one class, the
// accessor path decoded from the name (see Compiler.cxrPath).
public class PrimitiveCxr extends Primitive {
    public static final String[] NAMES = {
        "cdar", "cddr", "caaar", "caadr", "caddr", "cdaar", "cdadr", "cddar", "cdddr", "caaaar", "caaadr", "caadar", "caaddr", "cadaar", "cadadr", "caddar", "cadddr", "cdaaar", "cdaadr", "cdadar", "cdaddr", "cddaar", "cddadr", "cdddar", "cddddr"
    };

    private final String name;
    private final int path;

    public PrimitiveCxr(String name) {
        this.name = name;
        this.path = Compiler.cxrPath(name);
    }

    @Override
    public String name() {
        return name;
    }

    @Override
    public String info() {
        switch (name) {
        case "cdar":
            return "Syntax: (cdar pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the cdr of the car of pair. Equivalent to (cdr (car pair)).\n" +
            "Example:\n" +
            "  (cdar '((1 2) 3)) => (2)";
        case "cddr":
            return "Syntax: (cddr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the cdr of the cdr of pair. Equivalent to (cdr (cdr pair)).\n" +
            "Example:\n" +
            "  (cddr '(1 2 3)) => (3)";
        case "caaar":
            return "Syntax: (caaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car pair))). Accesses the car of the\n" +
            "car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaar '(((1 2) 3) 4)) => 1";
        case "caadr":
            return "Syntax: (caadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr pair))). Accesses the car of the\n" +
            "car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (caadr '(1 (2 3) 4)) => 2";
        case "caddr":
            return "Syntax: (caddr pair)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the car of the cdr of the cdr of pair. Equivalent to (car (cdr (cdr pair))). This is the third element of a list.\n" +
            "Example:\n" +
            "  (caddr '(1 2 3)) => 3";
        case "cdaar":
            return "Syntax: (cdaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car pair))). Accesses the cdr of the\n" +
            "car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaar '(((1 2) 3) 4)) => (2)";
        case "cdadr":
            return "Syntax: (cdadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr pair))). Accesses the cdr of the\n" +
            "car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdadr '(1 (2 3) 4)) => (3)";
        case "cddar":
            return "Syntax: (cddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car pair))). Accesses the cdr of the\n" +
            "cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddar '((1 2 3) 4)) => (3)";
        case "cdddr":
            return "Syntax: (cdddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr pair))). Returns the tail of a\n" +
            "list starting after the third element.\n" +
            "Example:\n" +
            "  (cdddr '(1 2 3 4 5)) => (4 5)";
        case "caaaar":
            return "Syntax: (caaaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car (car pair)))). Accesses the car of\n" +
            "four nested car operations on a pair structure.\n" +
            "Example:\n" +
            "  (caaaar '((((1 2) 3) 4) 5)) => 1";
        case "caaadr":
            return "Syntax: (caaadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (car (cdr pair)))). Accesses the car of\n" +
            "the car of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaadr '(1 ((2 3) 4) 5)) => 2";
        case "caadar":
            return "Syntax: (caadar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr (car pair)))). Accesses the car of\n" +
            "the car of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caadar '((1 (2 3)) 4)) => 2";
        case "caaddr":
            return "Syntax: (caaddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (car (cdr (cdr pair)))). Accesses the car of\n" +
            "the car of the third tail of a nested pair structure.\n" +
            "Example:\n" +
            "  (caaddr '(1 2 (3 4) 5)) => 3";
        case "cadaar":
            return "Syntax: (cadaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (car (car pair)))). Accesses the car of\n" +
            "the cdr of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cadaar '(((1 2) 3) 4)) => 2";
        case "cadadr":
            return "Syntax: (cadadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (car (cdr pair)))). Accesses the car of\n" +
            "the cdr of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cadadr '(1 (2 3) 4)) => 3";
        case "caddar":
            return "Syntax: (caddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (cdr (car pair)))). Accesses the car of\n" +
            "the cdr of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (caddar '((1 2 3) 4)) => 3";
        case "cadddr":
            return "Syntax: (cadddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (car (cdr (cdr (cdr pair)))). Returns the fourth\n" +
            "element of a list.\n" +
            "Example:\n" +
            "  (cadddr '(1 2 3 4 5)) => 4";
        case "cdaaar":
            return "Syntax: (cdaaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car (car pair)))). Accesses the cdr of\n" +
            "the car of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaaar '((((1 2) 3) 4) 5)) => (2)";
        case "cdaadr":
            return "Syntax: (cdaadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (car (cdr pair)))). Accesses the cdr of\n" +
            "the car of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaadr '(1 ((2 3) 4) 5)) => (3)";
        case "cdadar":
            return "Syntax: (cdadar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr (car pair)))). Accesses the cdr of\n" +
            "the car of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdadar '((1 (2 3)) 4)) => (3)";
        case "cdaddr":
            return "Syntax: (cdaddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (car (cdr (cdr pair)))). Accesses the cdr of\n" +
            "the car of the third tail of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdaddr '(1 2 (3 4) 5)) => (4)";
        case "cddaar":
            return "Syntax: (cddaar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car (car pair)))). Accesses the cdr of\n" +
            "the cdr of the car of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddaar '(((1 2 3) 4) 5)) => (3)";
        case "cddadr":
            return "Syntax: (cddadr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (car (cdr pair)))). Accesses the cdr of\n" +
            "the cdr of the car of the cdr of a nested pair structure.\n" +
            "Example:\n" +
            "  (cddadr '(1 (2 3 4) 5)) => (4)";
        case "cdddar":
            return "Syntax: (cdddar pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr (car pair)))). Accesses the cdr of\n" +
            "the cdr of the cdr of the car of a nested pair structure.\n" +
            "Example:\n" +
            "  (cdddar '((1 2 3 4) 5)) => (4)";
        case "cddddr":
            return "Syntax: (cddddr pair)\n" +
            "Library: (scheme cxr)\n" +
            "Description: Equivalent to (cdr (cdr (cdr (cdr pair)))). Returns the tail of\n" +
            "a list starting after the fourth element.\n" +
            "Example:\n" +
            "  (cddddr '(1 2 3 4 5 6)) => (5 6)";
        default:
            return "";
        }
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object v = arguments[0];
        for (int p = path; p != 1; p >>>= 1)
            v = (p & 1) != 0 ? Value.asPair(v).cdr : Value.asPair(v).car;
        return v;
    }
}
