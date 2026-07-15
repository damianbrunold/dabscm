using System.IO.Compression;
using System.Reflection;
using System.Text;

namespace scheme;

public class ModulePath
{
    // Assemblies (besides scheme.dll) that also carry embedded
    // `<prefix>.libraries.<name>.sld` resources. An embedding host (e.g.
    // an integration module that bundles its own Scheme libraries in its
    // own assembly) registers itself here so FindBuiltinLibraryStream
    // also searches it. This mirrors the Java build, where the classpath
    // is searched across all jars; on .NET manifest resources are
    // per-assembly, so extra assemblies must be registered explicitly.
    private static readonly List<Assembly> extraLibraryAssemblies = new();

    public static void RegisterLibraryAssembly(Assembly asm)
    {
        lock (extraLibraryAssemblies)
        {
            if (!extraLibraryAssemblies.Contains(asm))
                extraLibraryAssemblies.Add(asm);
        }
    }

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
        var name = moduleName.Replace(" ", "-") + ext;
        var s = typeof(ModulePath).Assembly.GetManifestResourceStream("scheme.libraries." + name);
        if (s != null) return s;
        var suffix = ".libraries." + name;
        Assembly[] extras;
        lock (extraLibraryAssemblies) extras = extraLibraryAssemblies.ToArray();
        foreach (var asm in extras)
        {
            // Preferred: <assembly-name>.libraries.<name> (RootNamespace
            // defaults to the assembly name).
            s = asm.GetManifestResourceStream(asm.GetName().Name + suffix);
            if (s != null) return s;
            // Fallback: any resource ending in .libraries.<name>, robust
            // to a non-default RootNamespace.
            foreach (var rn in asm.GetManifestResourceNames())
            {
                if (rn.EndsWith(suffix))
                {
                    s = asm.GetManifestResourceStream(rn);
                    if (s != null) return s;
                }
            }
        }
        return null;
    }
}
