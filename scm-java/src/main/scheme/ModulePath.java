package scheme;

import java.io.File;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class ModulePath {
    public static InputStream findBuiltinLibraryStream(String moduleName, String ext) {
        var resName = "/libraries/" + moduleName.replace(" ", "-") + ext;
        return ModulePath.class.getResourceAsStream(resName);
    }

    public static ModuleSource findModule(Modules modules, String module) {
        Object lst = Value.asPair(modules.getModuleRequired(null, "scm core").resolve(null, "*module-search-path*"));
        var moduleFile = module.replace(" ", "-");
        while (lst != Value.NIL) {
            String path = new String(Value.asString(Value.asPair(lst).car));
            if (path.endsWith(".slz")) {
                var source = findModuleInZip(path, moduleFile);
                if (source != null) return source;
            } else {
                var modulePath = path + "/" + moduleFile + ".scm";
                if (new File(modulePath).exists())
                    return ModuleSource.fromFile(modulePath);
                modulePath = path + "/" + moduleFile + ".sld";
                if (new File(modulePath).exists())
                    return ModuleSource.fromFile(modulePath);
            }
            lst = Value.asPair(lst).cdr;
        }
        return null;
    }

    private static ModuleSource findModuleInZip(String zipPath, String moduleFile) {
        if (!new File(zipPath).exists()) return null;
        try (var zip = new ZipFile(zipPath)) {
            for (var ext : new String[] { ".sld", ".scm" }) {
                var entryName = moduleFile + ext;
                ZipEntry entry = zip.getEntry(entryName);
                if (entry != null) {
                    try (var stream = zip.getInputStream(entry)) {
                        var content = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
                        return ModuleSource.fromZip(content, zipPath, entryName);
                    }
                }
            }
        } catch (Exception e) {
            // Invalid zip file — skip this search path entry
        }
        return null;
    }
}
