using System.Text;

namespace scheme;

public class PrimitiveLoadModule : Primitive
{
    private Modules modules;

    public PrimitiveLoadModule(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "%load-module";

    public override string Info() =>
        "Syntax: (%load-module module-name)\n" +
        "Library: (scm core)\n" +
        "Description: Internal primitive. Loads the named library module from an embedded .sld file or from the module search path. Returns #t if loaded successfully.\n" +
        "Example:\n" +
        "  (%load-module '(scheme base))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        var moduleName = Modules.AsModuleName(arguments[0]);
        // Serialize library loading so concurrent imports don't race on
        // the modules dict and per-module bindings. Reentrant lock allows
        // transitive (%load-module) calls from inside a load.
        lock (modules.LoadLock)
        {
        if (modules.HasModule(moduleName))
        {
            return Value.T;
        }
        if (modules.IsLoading(moduleName))
        {
            throw new SchemeError(pos,
                "import: circular dependency detected while loading '~a'", moduleName);
        }

        modules.MarkLoading(moduleName);
        var originalModule = modules.GetCurrentModule();
        try
        {
            var scheme = new Scheme(modules);

            // 1. Check embedded built-in .sld first
            var sldStream = ModulePath.FindBuiltinLibraryStream(moduleName, ".sld");
            if (sldStream != null)
            {
                modules.SetCurrentModule(moduleName);
                var text = new StreamReader(sldStream, Encoding.UTF8).ReadToEnd();
                scheme.EvalString(text, moduleName + ".sld");
                modules.UpdateModuleVar();
                return Value.T;
            }

            // 2. Check filesystem and .slz archives
            var source = ModulePath.FindModule(modules, moduleName);
            if (source != null)
            {
                modules.SetModuleLoadPath(moduleName, source.Directory);
                var scmCore = modules.GetModuleRequired(null, "scm core");
                var oldSearchPath = scmCore.Resolve(null, "*module-search-path*");
                try
                {
                    scmCore.Bind("*module-search-path*", new Pair(source.Directory.ToCharArray(), oldSearchPath));
                    modules.SetCurrentModule(moduleName);
                    if (source.Content != null)
                        scheme.EvalString(source.Content, source.FileName);
                    else
                        scheme.EvalFile(source.FilePath!);
                    modules.UpdateModuleVar();
                    return Value.T;
                }
                finally
                {
                    scmCore.Bind("*module-search-path*", oldSearchPath);
                }
            }

            throw new SchemeError(pos, "Modules: " + moduleName + " not available");
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, Name() + ": io failure");
        }
        finally
        {
            modules.UnmarkLoading(moduleName);
            modules.SetCurrentModule(originalModule.Name);
        }
        } // lock (modules.LoadLock)
    }
}
