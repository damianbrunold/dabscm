namespace scheme;

public class PrimitiveEval : Primitive
{
    private Modules modules;

    public PrimitiveEval(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "eval";
    }

    public override string Info()
    {
        return
            "Syntax: (eval expr) (eval expr environment)\n" +
            "Library: (scheme eval)\n" +
            "Description: Evaluates expr in the given environment specifier. If no environment is given, evaluates in the scm core environment.\n" +
            "Example:\n" +
            "  (eval '(+ 1 2) (environment '(scheme base))) => 3";
    }

    // Evaluate a top-level form, expanding (begin ...) sequentially so that
    // earlier forms (e.g. imports) affect the compilation environment of later forms.
    private object EvalSequentially(Scheme scheme, SourcePos? pos, object expr)
    {
        if (Value.IsPair(expr)
            && Value.IsSymbol(Value.AsPair(expr).First())
            && Value.AsSymbol(Value.AsPair(expr).First()).Equals("begin"))
        {
            object result = Value.NIL;
            object forms = Value.AsPair(expr).cdr;
            while (forms != Value.NIL)
            {
                result = EvalSequentially(scheme, pos, Value.AsPair(forms).car);
                forms = Value.AsPair(forms).cdr;
            }
            return result;
        }
        return scheme.Eval(pos, expr);
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        try
        {
            if (arguments.Length == 1)
            {
                var scm_core = modules.GetModuleRequired(pos, "scm core");
                Scheme scheme = new Scheme(new Modules(modules, scm_core));
                return EvalSequentially(scheme, pos, arguments[0]);
            }
            else
            {
                var moduleName = Modules.AsModuleName(arguments[1]);
                var module = modules.GetModule(moduleName);
                if (module == null)
                {
                    var scm_core = modules.GetModuleRequired(pos, "scm core");
                    var load_module = (Primitive) scm_core.Resolve(pos, "%load-module");
                    load_module.Apply(pos, new object[] { arguments[1] });
                    module = modules.GetModule(moduleName);
                }
                if (module == null)
                {
                    throw new SchemeError(pos, Name() + ": module ~a not found", moduleName);
                }
                Scheme scheme = new Scheme(new Modules(modules, module));
                return EvalSequentially(scheme, pos, arguments[0]);
            }
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "eval: internal error");
        }
    }
}
