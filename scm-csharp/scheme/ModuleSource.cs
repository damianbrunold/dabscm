namespace scheme;

public class ModuleSource
{
    public string? FilePath { get; }
    public string? Content { get; }
    public string Directory { get; }
    public string FileName { get; }

    private ModuleSource(string? filePath, string? content, string directory, string fileName)
    {
        FilePath = filePath;
        Content = content;
        Directory = directory;
        FileName = fileName;
    }

    public static ModuleSource FromFile(string filePath)
    {
        var dir = Path.GetDirectoryName(Path.GetFullPath(filePath))!;
        return new ModuleSource(filePath, null, dir, filePath);
    }

    public static ModuleSource FromZip(string content, string zipPath, string entryName)
    {
        var dir = Path.GetDirectoryName(Path.GetFullPath(zipPath))!;
        return new ModuleSource(null, content, dir, zipPath + "!/" + entryName);
    }
}
