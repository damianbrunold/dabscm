using System.Collections.Generic;
using System.Text;

namespace scheme;

public class Scheme : IEvaluator
{
    public static string[] CommandLineArgs = Array.Empty<string>();
    public static bool StrictImports = false;

    private Modules modules;
    private Compiler compiler;
    private VM vm;

    public static Scheme ForRepl()
    {
        var scheme = new Scheme();
        scheme.SetupUserMainModule();
        return scheme;
    }

    public static Scheme ForMinimal()
    {
        var scheme = new Scheme();
        scheme.SetupUserMinimalModule();
        return scheme;
    }

    public static Scheme ForProgram()
    {
        var scheme = new Scheme();
        scheme.SetupUserProgramModule();
        return scheme;
    }

    public static Scheme ForSysadmin()
    {
        var scheme = new Scheme();
        scheme.SetupUserSysadminModule();
        return scheme;
    }
    
    public Scheme()
    {
        this.modules = new Modules();
        this.compiler = new Compiler(modules);
        this.vm = new VM(modules);
        this.modules.Evaluator = this;

        // populate (scm core) — library.scm handles its own exports
        LoadLibraries();
    }

    public Scheme(Modules modules)
    {
        this.modules = modules;
        this.compiler = new Compiler(modules);
        this.vm = new VM(modules);
        this.modules.Evaluator = this;
    }

    public void DumpCallCounts()
    {
        var sorted = from entry in vm.call_counts orderby entry.Value ascending select entry;
        foreach (var entry in sorted)
        {
            Console.WriteLine(entry.Key + ": " + entry.Value);
        }
    }

    public void Snapshot()
    {
        modules.TakeSnapshot();
    }

    public void Reset()
    {
        if (modules.HasSnapshot())
        {
            modules.RestoreFromSnapshot();
            return;
        }
        if (this.modules.HasModule("user sysadmin"))
        {
            this.modules.ResetModules();
            SetupUserSysadminModule();
        }
        else if (this.modules.HasModule("user main"))
        {
            this.modules.ResetModules();
            SetupUserMainModule();
        }
        else if (this.modules.HasModule("user minimal"))
        {
            this.modules.ResetModules();
            SetupUserMinimalModule();
        }
        else
        {
            this.modules.ResetModules();
            SetupUserProgramModule();
        }
    }

    public object Read(TextStream reader)
    {
        var scm_core = modules.GetModuleRequired(reader.Pos(), "scm core");
        Primitive read = (Primitive) scm_core.Resolve(reader.Pos(), "read");
        return read.Apply(reader.Pos(), new object[] { reader });
    }

    public void Bind(string name, object value)
    {
        modules.GetCurrentModule().Bind(name, value);
    }

    public bool IsDebug(SourcePos? pos, string what)
    {
        var scm_core = modules.GetModuleRequired(pos, "scm core");
        if (scm_core.IsBound("*debug*"))
        {
            var dbg = scm_core.Resolve(pos, "*debug*");
            if (Value.IsPair(dbg))
            {
                object lst = Value.AsPair(dbg);
                while (lst != Value.NIL)
                {
                    var lstPair = Value.AsPair(lst);
                    if (Value.AsSymbol(lstPair.car) == what) return true;
                    lst = lstPair.cdr;
                }
            }
        }
        return false;
    }

    public void Debug(SourcePos? pos, string what, string message)
    {
        if (IsDebug(pos, what))
        {
            Console.WriteLine("DEBUG: " + message);
        }
    }
    
    public object Eval(SourcePos? pos, object expr)
    {
        Pair fn = compiler.Compile(pos, expr);
        object env = fn.Second();
        List<Instruction> instructions = (List<Instruction>) fn.Sixth();
        Lambda lambda = new Lambda(env, instructions);
        lambda.name = "<toplevel>";

        if (IsDebug(pos, "compile"))
        {
            new PrimitiveDisassemble(modules).Apply(pos, new object[] { lambda });
        }

        return vm.Execute(lambda);
    }

    public object Eval(object expr)
    {
        return Eval(null, expr);
    }

    public object EvalString(string str, string fname)
    {
        return EvalFile(new TextStream(new StringReader(str), fname), fname);
    }

    public object EvalFile(string file)
    {
        try
        {
            string contents = "";
            using (var reader = new TextStream(new StreamReader(new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.UTF8), file))
            {
                contents = reader.ReadToEnd() ?? "";
            }
            return EvalString(contents, file);
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (System.IO.IOException)
        {
            throw new SchemeError("Cannot evaluate file ~a: io error", file);
        }
        catch (Exception)
        {
            throw new SchemeError("Cannot evaluate file ~a: internal error", file);
        }
    }

    public object EvalFile(TextStream reader, string file)
    {
        var pos = reader.Pos();
        object expr = Read(reader);
        object value = Value.F;
        while (!expr.Equals(Value.EOF))
        {
            value = Eval(pos, expr);
            pos = reader.Pos();
            expr = Read(reader);
        }
        return value;
    }

    public void SetupUserMainModule()
    {
        var user_main = new Module("user main");
        modules.SetCurrentModule("user main");
        var libs = new string[] {
            "(scheme base)",
            "(scheme file)",
            "(scheme process-context)",
            "(scheme read)",
            "(scheme time)",
            "(scheme write)",
            "(scm fs)",
            "(scm io)",
            "(scm list)",
            "(scm string)",
            "(scm doc)",
            "(srfi 13)"
        };
        foreach (var lib in libs)
        {
            EvalString("(import " + lib + ")", lib);
        }
        modules.UpdateModuleVar();
        modules.SetCurrentModule("user main");
    }
    
    public void SetupUserMinimalModule()
    {
        var user_minimal = new Module("user minimal");
        modules.SetCurrentModule("user minimal");
        EvalString("(import (scheme base))", "(scheme base)");
        EvalString("(import (scheme write))", "(scheme base)");
        modules.UpdateModuleVar();
        modules.SetCurrentModule("user minimal");
    }
    
    public void SetupUserProgramModule()
    {
        var scm_core = modules.GetModuleRequired(null, "scm core");
        modules.SetCurrentModule("user program");
    }

    public void SetupUserSysadminModule()
    {
        var user_sysadmin = new Module("user sysadmin");
        modules.SetCurrentModule("user sysadmin");
        var libs = new string[] {
            "(scheme base)",
            "(scheme file)",
            "(scheme process-context)",
            "(scheme read)",
            "(scheme time)",
            "(scheme write)",
            "(scm sysadmin)",
            "(scm io)",
            "(scm glob)",
            "(scm string)",
            "(scm doc)",
            "(srfi 1)",
            "(srfi 13)"
        };
        foreach (var lib in libs)
        {
            EvalString("(import " + lib + ")", lib);
        }
        modules.UpdateModuleVar();
        modules.SetCurrentModule("user sysadmin");
    }

    public void LoadLibraries()
    {
        var assembly = typeof(Scheme).Assembly;
        EvalFile(new TextStream(new StreamReader(assembly.GetManifestResourceStream("scheme.library.scm")!), "library.scm"), "{library}");
    }
}
