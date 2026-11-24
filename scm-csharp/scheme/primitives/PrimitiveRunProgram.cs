using System.Diagnostics;

namespace scheme;

public class PrimitiveRunProgram : Primitive
{
    private Modules modules;

    public PrimitiveRunProgram(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "run-program";
    }

    public override string Info()
    {
        return
            "Syntax: (run-program cmd [options])\n" +
            "Library: (scm system)\n" +
            "Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. The program inherits the caller's standard input, output and error (so it can use the terminal; start-program gives it a private stdin instead). options is an alist with optional keys: 'work-dir <path>, 'env <alist of (name value) string pairs added to the child environment>, 'stdin <string> (the text the program reads), 'stdin-file <path>, 'stdout <path>, 'stderr <path> (the program writes to these files; output not redirected goes to the terminal as it is written), 'stderr 'stdout (stderr goes where stdout goes), 'append #t (the files are appended to). Returns #f on failure.\n" +
            "Example:\n" +
            "  (run-program '(\"echo\" \"hello\")) => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.AsPair(arguments[0]);
        object options = Value.NIL;
        if (arguments.Length > 1)
        {
            options = arguments[1];
        }
        try
        {
            string cmd = new String(Value.AsString(cmdline.car));
            List<string> args = new();

            object p = cmdline.cdr;
            while (p != Value.NIL)
            {
                var pp = Value.AsPair(p);
                args.Add(new String(Value.AsString(pp.car)));
                p = pp.cdr;
            }

            var process = new Process();
            process.StartInfo = ProcUtil.CreateStartInfo(cmd, args);
            var redirects = ProcessRedirects.Parse(options);
            redirects.Apply(process.StartInfo);

            if (options != Value.NIL)
            {
                // no 'work-dir -> inherit the current directory
                var val = PrimitiveGetProperty.GetProperty(options, "work-dir", Value.F);
                if (!val.Equals(Value.F))
                {
                    process.StartInfo.WorkingDirectory = new String(Value.AsString(val));
                }
                ProcessEnvUtil.Apply(process.StartInfo, options);
            }

            process.Start();
            redirects.Start(process);
            process.WaitForExit();
            redirects.Wait();
            return (long) process.ExitCode;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }

}
