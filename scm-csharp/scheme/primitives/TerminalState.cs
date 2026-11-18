using System.Runtime.InteropServices;

namespace scheme;

/// Shared terminal state: SIGWINCH tracking and a cached terminal size.
internal static class TerminalState
{
    private static long resizeCount = 0;
    private static bool installed = false;
    private static bool installAttempted = false;
    private static PosixSignalRegistration? registration;
    internal static volatile object? CachedSize = null;
    private static readonly object Lock = new();

    internal static bool InstallResizeHandler()
    {
        lock (Lock)
        {
            if (installAttempted) return installed;
            installAttempted = true;
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return false;
            try
            {
                registration = PosixSignalRegistration.Create(PosixSignal.SIGWINCH, ctx =>
                {
                    CachedSize = null;
                    Interlocked.Increment(ref resizeCount);
                    ctx.Cancel = true;
                });
                installed = true;
            }
            catch
            {
                installed = false;
            }
            return installed;
        }
    }

    internal static bool ResizeTracked => installed;

    internal static long ResizeCount => Interlocked.Read(ref resizeCount);
}
