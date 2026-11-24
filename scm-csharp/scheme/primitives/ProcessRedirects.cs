using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace scheme;

// The redirection options of run-program and start-program: 'stdin <string>,
// 'stdin-file <path>, 'stdout <path>, 'stderr <path> or 'stdout, 'append #t.
// .NET cannot hand a file to the child as its stream, so a redirected stream
// is a pipe that a task copies as the data comes (the file is written while
// the program runs, as on the JVM and natively).
internal sealed class ProcessRedirects
{
    private string? stdinText;
    private string? stdinFile;
    private string? stdoutFile;
    private string? stderrFile;
    private bool stderrToStdout;
    private bool append;
    private readonly List<Task> pumps = new();
    private readonly object writeLock = new();

    public static ProcessRedirects Parse(object options)
    {
        var r = new ProcessRedirects();
        if (options == Value.NIL) return r;
        r.append = !PrimitiveGetProperty.GetProperty(options, "append", Value.F).Equals(Value.F);
        var v = PrimitiveGetProperty.GetProperty(options, "stdin", Value.F);
        if (!v.Equals(Value.F)) r.stdinText = new string(Value.AsString(v));
        v = PrimitiveGetProperty.GetProperty(options, "stdin-file", Value.F);
        if (!v.Equals(Value.F)) r.stdinFile = new string(Value.AsString(v));
        v = PrimitiveGetProperty.GetProperty(options, "stdout", Value.F);
        if (!v.Equals(Value.F)) r.stdoutFile = new string(Value.AsString(v));
        v = PrimitiveGetProperty.GetProperty(options, "stderr", Value.F);
        if (Value.IsSymbol(v) && Value.AsSymbol(v) == "stdout") r.stderrToStdout = true;
        else if (!v.Equals(Value.F)) r.stderrFile = new string(Value.AsString(v));
        return r;
    }

    // start-program's 'log-file takes stdout and stderr
    public void DropOutput()
    {
        stdoutFile = null;
        stderrFile = null;
        stderrToStdout = false;
    }

    public bool RedirectsStdin => stdinText != null || stdinFile != null;

    // Sets the streams the options name to pipes
    public void Apply(ProcessStartInfo psi)
    {
        if (RedirectsStdin) psi.RedirectStandardInput = true;
        if (stdoutFile != null) psi.RedirectStandardOutput = true;
        if (stderrFile != null || stderrToStdout) psi.RedirectStandardError = true;
    }

    private FileStream Output(string path) =>
        new FileStream(path, append ? FileMode.Append : FileMode.Create, FileAccess.Write, FileShare.ReadWrite);

    // After the start: the tasks feeding stdin and copying the output
    public void Start(Process proc)
    {
        if (stdinText != null || stdinFile != null)
        {
            var input = proc.StandardInput.BaseStream;
            string? text = stdinText;
            string? file = stdinFile;
            pumps.Add(Task.Run(() =>
            {
                try
                {
                    if (text != null)
                    {
                        var bytes = new UTF8Encoding(false).GetBytes(text);
                        input.Write(bytes, 0, bytes.Length);
                    }
                    else
                    {
                        using var f = new FileStream(file!, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                        f.CopyTo(input);
                    }
                }
                catch (IOException) { /* the child did not read all of it */ }
                finally
                {
                    try { input.Close(); } catch (IOException) { }
                }
            }));
        }
        Stream? outTarget = null;
        if (stdoutFile != null)
        {
            outTarget = Output(stdoutFile);
            pumps.Add(Pump(proc.StandardOutput.BaseStream, outTarget, stderrToStdout ? 2 : 1));
        }
        if (stderrFile != null)
        {
            pumps.Add(Pump(proc.StandardError.BaseStream, Output(stderrFile), 1));
        }
        else if (stderrToStdout)
        {
            var target = outTarget ?? Console.OpenStandardOutput();
            pumps.Add(Pump(proc.StandardError.BaseStream, target, outTarget != null ? 2 : 0));
        }
    }

    // users: how many pumps write to target (closed by the last), 0: never closed
    private int sharedUsers = 0;

    private Task Pump(Stream from, Stream to, int users)
    {
        if (users == 2) sharedUsers = 2;
        return Task.Run(() =>
        {
            var buf = new byte[8192];
            try
            {
                int n;
                while ((n = from.Read(buf, 0, buf.Length)) > 0)
                {
                    lock (writeLock)
                    {
                        to.Write(buf, 0, n);
                        to.Flush();
                    }
                }
            }
            catch (IOException) { }
            finally
            {
                lock (writeLock)
                {
                    if (users == 1) to.Dispose();
                    else if (users == 2 && --sharedUsers == 0) to.Dispose();
                }
            }
        });
    }

    // run-program: the output is complete when the program has ended
    public void Wait(int timeoutMs = -1)
    {
        try { Task.WaitAll(pumps.ToArray(), timeoutMs); } catch (AggregateException) { }
    }

    // start-program's 'new-group #t on POSIX: the program runs in a process
    // group of its own (perl's setpgrp, else setsid, then exec: the pid stays
    // the program's), so that Ctrl+C at the terminal does not reach it. On
    // Windows ProcessStartInfo.CreateNewProcessGroup does it.
    public static (string, List<string>) NewGroupCommand(string cmd, List<string> args)
    {
        bool hasSep = cmd.Contains('/');
        if (hasSep ? !File.Exists(cmd) : FindExecutable(cmd) == null)
            throw new InvalidOperationException("Cannot run program \"" + cmd + "\": not found");
        var all = new List<string>();
        string prog;
        if (FindExecutable("perl") != null)
        {
            prog = "perl";
            all.Add("-e");
            all.Add("setpgrp(0, 0); exec { $ARGV[0] } @ARGV; print STDERR \"$ARGV[0]: $!\\n\"; exit 127");
            all.Add("--");
        }
        else if (FindExecutable("setsid") != null)
        {
            prog = "setsid";
        }
        else
        {
            throw new InvalidOperationException("'new-group needs perl or setsid");
        }
        all.Add(cmd);
        all.AddRange(args);
        return (prog, all);
    }

    private static string? FindExecutable(string prog)
    {
        var path = Environment.GetEnvironmentVariable("PATH");
        if (path == null) return null;
        foreach (var dir in path.Split(Path.PathSeparator))
        {
            if (dir.Length == 0) continue;
            var f = Path.Combine(dir, prog);
            if (File.Exists(f)) return f;
        }
        return null;
    }
}
