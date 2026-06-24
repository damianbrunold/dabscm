using System;
using System.Diagnostics;

namespace scheme;

internal static class ProcessEnvUtil
{
    // Applies the optional 'env option to a ProcessStartInfo. The value is an
    // alist of (name value) or (name . value) string pairs; each is added to
    // (or overrides) the child's inherited environment. Absent / NIL is a
    // no-op. Requires UseShellExecute = false (the process primitives set it).
    // Used by run-program, run-program/capture and start-program so callers can
    // pass e.g. PGPASSWORD or a server URL to a child (and, since children
    // inherit the augmented environment, transitively to its own children).
    public static void Apply(ProcessStartInfo psi, object options)
    {
        var envVal = PrimitiveGetProperty.GetProperty(options, "env", Value.F);
        if (envVal.Equals(Value.F) || envVal == Value.NIL) return;
        object p = envVal;
        while (p != Value.NIL)
        {
            var entry = Value.AsPair(p);
            var kv = Value.AsPair(entry.car);
            string name = new String(Value.AsString(kv.car));
            string value = Value.IsPair(kv.cdr)
                ? new String(Value.AsString(Value.AsPair(kv.cdr).car))
                : new String(Value.AsString(kv.cdr));
            psi.EnvironmentVariables[name] = value;
            p = entry.cdr;
        }
    }
}
