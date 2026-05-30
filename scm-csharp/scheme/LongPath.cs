using System.IO;

namespace scheme;

/// <summary>
/// Windows extended-length path helpers. On Windows, file APIs are limited to
/// MAX_PATH (260 chars) unless paths are prefixed with \\?\ (or \\?\UNC\ for
/// UNC paths), which the .NET file APIs accept. Off Windows these are no-ops,
/// so behaviour on Linux/macOS is unchanged.
/// </summary>
public static class LongPath
{
    /// <summary>
    /// Prefix an absolute path with \\?\ on Windows so it bypasses MAX_PATH.
    /// No-op off Windows, on empty input, or when already prefixed.
    /// </summary>
    public static string Wlp(string path)
    {
        if (!System.OperatingSystem.IsWindows() || string.IsNullOrEmpty(path)) return path;
        if (path.StartsWith(@"\\?\")) return path;
        var abs = Path.GetFullPath(path);
        if (abs.StartsWith(@"\\")) return @"\\?\UNC\" + abs.Substring(2);
        return @"\\?\" + abs;
    }

    /// <summary>
    /// Inverse of <see cref="Wlp"/>: strip a \\?\ extended-length prefix if
    /// present, so the prefix never leaks into strings handed back to Scheme.
    /// No-op off Windows or on empty input.
    /// </summary>
    public static string Strip(string path)
    {
        if (!System.OperatingSystem.IsWindows() || string.IsNullOrEmpty(path)) return path;
        if (path.StartsWith(@"\\?\UNC\")) return @"\\" + path.Substring(8);
        if (path.StartsWith(@"\\?\")) return path.Substring(4);
        return path;
    }
}
