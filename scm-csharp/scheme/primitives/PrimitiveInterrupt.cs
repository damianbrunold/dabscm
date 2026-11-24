using System;
using System.Threading;

namespace scheme;

// set-interrupt-handler! and take-interrupt! ((scm system)): what Ctrl+C
// (SIGINT; Ctrl+Break on Windows) does, through Console.CancelKeyPress:
// 'ignore and 'record cancel the termination, 'default lets it happen.
// Child processes are not affected.
public class PrimitiveInterrupt : Primitive
{
    private static readonly string[] Modes = { "default", "ignore", "record" };
    private static volatile int mode = 0;
    private static int interrupted = 0;
    private static bool installed = false;
    private static readonly object installLock = new();

    private readonly string name;

    public PrimitiveInterrupt(string name)
    {
        this.name = name;
    }

    public override string Name() => name;

    public override string Info()
    {
        if (name == "take-interrupt!")
            return
                "Syntax: (take-interrupt!)\n" +
                "Library: (scm system)\n" +
                "Description: Returns #t if an interrupt (Ctrl+C) was recorded since the last call\n" +
                "  (set-interrupt-handler! 'record), else #f.\n" +
                "Example:\n" +
                "  (when (take-interrupt!) (display \"^C\"))";
        return
            "Syntax: (set-interrupt-handler! mode)\n" +
            "Library: (scm system)\n" +
            "Description: Sets what an interrupt (Ctrl+C, SIGINT; Ctrl+Break on Windows) does:\n" +
            "  'default ends the program (as at the start), 'ignore does nothing, 'record\n" +
            "  records it for take-interrupt!. Child processes are not affected: a program\n" +
            "  run in the foreground still gets Ctrl+C. Returns the mode before.\n" +
            "Example:\n" +
            "  (set-interrupt-handler! 'ignore) => default\n" +
            "  (run-program '(\"sleep\" \"10\"))     ; Ctrl+C ends sleep, not the caller\n" +
            "  (set-interrupt-handler! 'default) => ignore";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (name == "take-interrupt!")
        {
            CheckArgs(pos, arguments, 0, 0);
            return Interlocked.Exchange(ref interrupted, 0) != 0;
        }
        CheckArgs(pos, arguments, 1, 1);
        int m = Value.IsSymbol(arguments[0]) ? Array.IndexOf(Modes, Value.AsSymbol(arguments[0])) : -1;
        if (m < 0)
            throw new SchemeError(pos, "set-interrupt-handler!: expected 'default, 'ignore or 'record");
        int before = mode;
        mode = m;
        lock (installLock)
        {
            if (!installed && m != 0)
            {
                Console.CancelKeyPress += (sender, e) =>
                {
                    int cur = mode;
                    if (cur == 0) return;
                    if (cur == 2) Interlocked.Exchange(ref interrupted, 1);
                    // Ctrl+Break may not be cancelable
                    try { e.Cancel = true; } catch (InvalidOperationException) { }
                };
                installed = true;
            }
        }
        return Value.Intern(Modes[before]);
    }
}
