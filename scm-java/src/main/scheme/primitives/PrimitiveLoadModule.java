package scheme.primitives;

import java.io.File;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import scheme.ModulePath;
import scheme.ModuleSource;
import scheme.Modules;
import scheme.Pair;
import scheme.Primitive;
import scheme.Scheme;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveLoadModule extends Primitive {
    private Modules modules;

    public PrimitiveLoadModule(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "%load-module";
    }

    @Override
    public String info() {
        return "Syntax: (%load-module module-name)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Loads the named library module from an embedded .sld file or from the module search path. Returns #t if loaded successfully.\n" +
               "Example:\n" +
               "  (%load-module '(scheme base))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        var moduleName = Modules.asModuleName(arguments[0]);
        if (modules.hasModule(moduleName))
            return Value.T;
        if (modules.isLoading(moduleName)) {
            throw new SchemeError(pos,
                "import: circular dependency detected while loading '~a'", moduleName);
        }

        modules.markLoading(moduleName);
        var originalModule = modules.getCurrentModule();
        try {
            var scheme = new Scheme(modules);

            // 1. Check embedded built-in .sld first
            InputStream sldStream = ModulePath.findBuiltinLibraryStream(moduleName, ".sld");
            if (sldStream != null) {
                modules.setCurrentModule(moduleName);
                var text = new String(sldStream.readAllBytes(), StandardCharsets.UTF_8);
                scheme.evalString(text, moduleName + ".sld");
                modules.updateModuleVar();
                return Value.T;
            }

            // 2. Check filesystem and .slz archives
            var source = ModulePath.findModule(modules, moduleName);
            if (source != null) {
                modules.setModuleLoadPath(moduleName, source.getDirectory());
                var scmCore = modules.getModuleRequired(null, "scm core");
                var oldSearchPath = scmCore.resolve(null, "*module-search-path*");
                try {
                    scmCore.bind("*module-search-path*", new Pair(source.getDirectory().toCharArray(), oldSearchPath));
                    modules.setCurrentModule(moduleName);
                    if (source.getContent() != null)
                        scheme.evalString(source.getContent(), source.getFileName());
                    else
                        scheme.evalFile(new File(source.getFilePath()));
                    modules.updateModuleVar();
                    return Value.T;
                } finally {
                    scmCore.bind("*module-search-path*", oldSearchPath);
                }
            }

            throw new SchemeError(pos, "Modules: " + moduleName + " not available");
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure");
        } finally {
            modules.unmarkLoading(moduleName);
            modules.setCurrentModule(originalModule.getName());
        }
    }
}
