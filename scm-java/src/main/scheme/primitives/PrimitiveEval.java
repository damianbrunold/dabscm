package scheme.primitives;

import scheme.*;

public class PrimitiveEval extends Primitive {
    private Modules modules;

    public PrimitiveEval(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "eval";
    }

    @Override
    public String info() {
        return "Syntax: (eval expr) (eval expr environment)\n" +
               "Library: (scheme eval)\n" +
               "Description: Evaluates expr in the given environment specifier. If no environment is given, evaluates in the scm core environment.\n" +
               "Example:\n" +
               "  (eval '(+ 1 2) (environment '(scheme base))) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        try {
            if (arguments.length == 1) {
                Scheme scheme = new Scheme(modules);
                return evalSequentially(scheme, pos, arguments[0]);
            }

            var moduleName = Modules.asModuleName(arguments[1]);
            var module = modules.getModule(moduleName);
            if (module == null) {
                var loadModule = (Primitive) modules.getModuleRequired(pos, "scm core").resolve(pos, "%load-module");
                loadModule.apply(pos, new Object[] { arguments[1] });
                module = modules.getModule(moduleName);
            }
            if (module == null)
                throw new SchemeError(pos, name() + ": module not found: ~a", moduleName);
            var newModules = new Modules(modules, module);
            Scheme scheme = new Scheme(newModules);
            return evalSequentially(scheme, pos, arguments[0]);
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, "eval: internal error");
        }
    }

    // Evaluate a top-level form, expanding (begin ...) sequentially so that
    // earlier forms (e.g. imports) affect the compilation environment of later forms.
    private Object evalSequentially(Scheme scheme, SourcePos pos, Object expr) throws Exception {
        if (Value.isPair(expr)) {
            Pair p = Value.asPair(expr);
            if (Value.isSymbol(p.car) && Value.asSymbol(p.car).equals("begin")) {
                Object result = Value.NIL;
                Object forms = p.cdr;
                while (forms != Value.NIL) {
                    Pair formsPair = Value.asPair(forms);
                    result = evalSequentially(scheme, pos, formsPair.car);
                    forms = formsPair.cdr;
                }
                return result;
            }
        }
        return scheme.eval(pos, expr);
    }
}
