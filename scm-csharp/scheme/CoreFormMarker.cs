namespace scheme;

/// <summary>
/// Sentinel value for core syntax forms (if, let, lambda, etc.) in the module
/// binding system. Allows core forms to be exported/imported through the R7RS
/// module system without having a runtime value.
/// </summary>
public class CoreFormMarker
{
    public readonly string Name;
    public readonly string? Docstring;

    private static readonly Dictionary<string, string> Docstrings = new()
    {
        ["quote"] =
            "Syntax: (quote datum) | 'datum\n" +
            "Library: (scheme base)\n" +
            "Description: Returns datum without evaluating it. The reader abbreviation\n" +
            "  'datum is equivalent to (quote datum).\n" +
            "Example:\n" +
            "  (quote (1 2 3)) => (1 2 3)\n" +
            "  'hello => hello",

        ["quasiquote"] =
            "Syntax: (quasiquote template) | `template\n" +
            "Library: (scheme base)\n" +
            "Description: Returns template with unquoted expressions evaluated. Use\n" +
            "  ,expr to insert a value and ,@expr to splice a list. The reader\n" +
            "  abbreviation `template is equivalent to (quasiquote template).\n" +
            "Example:\n" +
            "  (let ((x 1)) `(a ,x c)) => (a 1 c)\n" +
            "  (let ((xs '(1 2))) `(a ,@xs c)) => (a 1 2 c)",

        ["if"] =
            "Syntax: (if test consequent) | (if test consequent alternate)\n" +
            "Library: (scheme base)\n" +
            "Description: Evaluates test. If the result is a true value, consequent is\n" +
            "  evaluated and its value is returned. Otherwise, alternate is evaluated and\n" +
            "  its value is returned. If test yields #f and no alternate is specified,\n" +
            "  the result is unspecified.\n" +
            "Example:\n" +
            "  (if (> 3 2) 'yes 'no) => yes\n" +
            "  (if (> 2 3) 'yes 'no) => no",

        ["set!"] =
            "Syntax: (set! variable expression)\n" +
            "Library: (scheme base)\n" +
            "Description: Evaluates expression and stores the result in the location to\n" +
            "  which variable is bound. variable must be bound either in some enclosing\n" +
            "  scope or at the top level. The result of the set! expression is\n" +
            "  unspecified.\n" +
            "Example:\n" +
            "  (let ((x 1)) (set! x 2) x) => 2",

        ["begin"] =
            "Syntax: (begin expression ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Evaluates expressions sequentially from left to right. The\n" +
            "  value of the last expression is returned. begin can also appear as a\n" +
            "  splicing form at the top level or at the beginning of a body, in which\n" +
            "  case the forms inside the begin are spliced into the surrounding body.\n" +
            "Example:\n" +
            "  (begin (define x 1) (+ x 2)) => 3",

        ["lambda"] =
            "Syntax: (lambda formals body)\n" +
            "Library: (scheme base)\n" +
            "Description: Creates a procedure. formals is a list of parameters, a single\n" +
            "  symbol for a rest parameter, or a dotted pair for required plus rest\n" +
            "  parameters. When the procedure is called, the arguments are bound to the\n" +
            "  parameters and the body is evaluated. The value of the last expression in\n" +
            "  the body is returned.\n" +
            "Example:\n" +
            "  ((lambda (x y) (+ x y)) 3 4) => 7\n" +
            "  ((lambda xs xs) 1 2 3) => (1 2 3)",

        ["define"] =
            "Syntax: (define variable expression) | (define (name formals) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Defines a variable binding. The first form evaluates expression\n" +
            "  and binds the result to variable. The second form is equivalent to\n" +
            "  (define name (lambda (formals) body)) and creates a procedure binding.\n" +
            "Example:\n" +
            "  (define x 42)\n" +
            "  (define (square n) (* n n))",

        ["define-syntax"] =
            "Syntax: (define-syntax keyword transformer)\n" +
            "Library: (scheme base)\n" +
            "Description: Defines a syntax binding, associating keyword with the given\n" +
            "  macro transformer. transformer is typically a syntax-rules or\n" +
            "  syntax-case expression.\n" +
            "Example:\n" +
            "  (define-syntax my-and\n" +
            "    (syntax-rules ()\n" +
            "      ((_) #t)\n" +
            "      ((_ e) e)\n" +
            "      ((_ e1 e2 ...) (if e1 (my-and e2 ...) #f))))",

        ["let"] =
            "Syntax: (let ((variable init) ...) body) | (let name ((variable init) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Binds each variable to the value of the corresponding init\n" +
            "  expression and evaluates body in the extended environment. The init\n" +
            "  expressions are evaluated in the current environment (not the extended\n" +
            "  one). Named let binds the variables and also binds name to a procedure\n" +
            "  that, when called, rebinds the variables and re-evaluates the body.\n" +
            "Example:\n" +
            "  (let ((x 1) (y 2)) (+ x y)) => 3\n" +
            "  (let loop ((n 5) (acc 1)) (if (= n 0) acc (loop (- n 1) (* acc n)))) => 120",

        ["let*"] =
            "Syntax: (let* ((variable init) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Like let, but the bindings are performed sequentially from\n" +
            "  left to right, and each init expression is evaluated in an environment in\n" +
            "  which the previous bindings are visible.\n" +
            "Example:\n" +
            "  (let* ((x 1) (y (+ x 1))) (+ x y)) => 3",

        ["letrec"] =
            "Syntax: (letrec ((variable init) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Binds each variable and evaluates the init expressions in an\n" +
            "  environment where all variables are bound. The order of evaluation of the\n" +
            "  init expressions is unspecified. Useful for defining mutually recursive\n" +
            "  procedures.\n" +
            "Example:\n" +
            "  (letrec ((even? (lambda (n) (if (= n 0) #t (odd? (- n 1)))))\n" +
            "           (odd? (lambda (n) (if (= n 0) #f (even? (- n 1))))))\n" +
            "    (even? 10)) => #t",

        ["letrec*"] =
            "Syntax: (letrec* ((variable init) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Like letrec, but the init expressions are evaluated\n" +
            "  sequentially from left to right. Each init is evaluated in an environment\n" +
            "  where all variables are bound, but only the preceding init values are\n" +
            "  guaranteed to be available.\n" +
            "Example:\n" +
            "  (letrec* ((x 1) (y (+ x 1))) (+ x y)) => 3",

        ["let-syntax"] =
            "Syntax: (let-syntax ((keyword transformer) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Binds each keyword to the corresponding macro transformer\n" +
            "  and evaluates body in the extended syntactic environment. The bindings\n" +
            "  are not visible in the transformer expressions.\n" +
            "Example:\n" +
            "  (let-syntax ((swap! (syntax-rules ()\n" +
            "                        ((_ a b) (let ((t a)) (set! a b) (set! b t))))))\n" +
            "    (let ((x 1) (y 2)) (swap! x y) (list x y))) => (2 1)",

        ["letrec-syntax"] =
            "Syntax: (letrec-syntax ((keyword transformer) ...) body)\n" +
            "Library: (scheme base)\n" +
            "Description: Like let-syntax, but the bindings are visible in the\n" +
            "  transformer expressions, allowing mutually recursive macro definitions.\n" +
            "Example:\n" +
            "  (letrec-syntax ((my-or (syntax-rules ()\n" +
            "                           ((_) #f)\n" +
            "                           ((_ e) e)\n" +
            "                           ((_ e1 e2 ...) (let ((t e1)) (if t t (my-or e2 ...)))))))\n" +
            "    (my-or #f #f 42)) => 42",

        ["cond-expand"] =
            "Syntax: (cond-expand (feature-requirement body ...) ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Evaluates the body of the first clause whose feature\n" +
            "  requirement is satisfied. Feature requirements can be feature identifiers,\n" +
            "  (library <name>) tests, or boolean combinations using and, or, and not.\n" +
            "  An optional (else body ...) clause provides a default.\n" +
            "Example:\n" +
            "  (cond-expand\n" +
            "    (r7rs \"R7RS\")\n" +
            "    (else \"unknown\")) => \"R7RS\"",
    };

    public CoreFormMarker(string name)
    {
        this.Name = name;
        Docstrings.TryGetValue(name, out string? doc);
        this.Docstring = doc;
    }

    public override string ToString()
    {
        return "#<core-form " + Name + ">";
    }
}
