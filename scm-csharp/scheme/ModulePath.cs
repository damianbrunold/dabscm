using System.IO.Compression;
using System.Text;

namespace scheme;

public class ModulePath
{
    public static ModuleSource? FindModule(Modules modules, string module)
    {
        var scm_core = modules.GetModuleRequired(null, "scm core");
        object lst = Value.AsPair(scm_core.Resolve(null, "*module-search-path*"));
        var moduleFile = module.Replace(" ", "-");
        while (lst != Value.NIL)
        {
            string path = new string(Value.AsString(Value.AsPair(lst).car));
            if (path.EndsWith(".slz"))
            {
                var source = FindModuleInZip(path, moduleFile);
                if (source != null) return source;
            }
            else
            {
                var modulePath = Path.Join(path, moduleFile + ".sld");
                if (File.Exists(modulePath))
                    return ModuleSource.FromFile(modulePath);
                modulePath = Path.Join(path, moduleFile + ".scm");
                if (File.Exists(modulePath))
                    return ModuleSource.FromFile(modulePath);
            }
            lst = Value.AsPair(lst).cdr;
        }
        return null;
    }

    private static ModuleSource? FindModuleInZip(string zipPath, string moduleFile)
    {
        if (!File.Exists(zipPath)) return null;
        try
        {
            using var archive = ZipFile.OpenRead(zipPath);
            foreach (var ext in new[] { ".sld", ".scm" })
            {
                var entryName = moduleFile + ext;
                var entry = archive.GetEntry(entryName);
                if (entry != null)
                {
                    using var stream = entry.Open();
                    using var reader = new StreamReader(stream, Encoding.UTF8);
                    var content = reader.ReadToEnd();
                    return ModuleSource.FromZip(content, zipPath, entryName);
                }
            }
        }
        catch (Exception)
        {
            // Invalid zip file — skip this search path entry
        }
        return null;
    }

    public static Stream? FindBuiltinLibraryStream(string moduleName, string ext)
    {
        var resName = "scheme.libraries." + moduleName.Replace(" ", "-") + ext;
        return typeof(ModulePath).Assembly.GetManifestResourceStream(resName);
    }
}
