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
            "Syntax: (run-program cmd)\n" +
            "Library: (scm system)\n" +
            "Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. Returns #f on failure.\n" +
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
            process.StartInfo = new ProcessStartInfo(cmd, args);

            if (options != Value.NIL)
            {
                var val = PrimitiveGetProperty.GetProperty(
                    options,
                    "work-dir",
                    "."
                );
                var workdir = new String(Value.AsString(val));
                process.StartInfo.WorkingDirectory = workdir;
            }

            process.Start();
            process.WaitForExit();
            return (long) process.ExitCode;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }

}
