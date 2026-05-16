using System.Globalization;

namespace scheme;

public class PrimitiveDisassemble : Primitive
{
    private Modules modules;

    public PrimitiveDisassemble(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "disassemble";
    }

    public override string Info()
    {
        return
            "Syntax: (disassemble fn) (disassemble fn port)\n" +
            "Library: (scm compile)\n" +
            "Description: Writes a human-readable disassembly of the bytecode of the lambda fn to the current output port (or to port if given).\n" +
            "Example:\n" +
            "  (disassemble (lambda (x) (+ x 1)))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Lambda fn = Value.AsLambda(arguments[0]);
        TextWriter port;
        if (arguments.Length == 1)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsOutputPort(scmcore.Resolve(pos, "*output-port*"));
        }
        else
        {
            port = Value.AsOutputPort(arguments[1]);
        }
        try
        {
            port.Write(fn.name + "\n");
            port.Write("env: " + Value.PrintRep(fn.env) + "\n");
            WriteCode(port, fn.code, "");
            port.Flush();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + ": failed due to: ~s", e.Message);
        }
    }

    private void WriteCode(TextWriter port, List<Instruction> code, string indent)
    {
        int index = 0;
        foreach (Instruction instruction in code)
        {
            if (instruction.opcode == Opcode.FN)
            {
                port.Write(
                    String.Format(
                        "{0}{1} {2}\n",
                        indent,
                        index + ":",
                        instruction.opcode.ToString(),
                        CultureInfo.InvariantCulture
                    )
                );
                port.Write(
                    indent + "    env: "
                    + Value.AsPair(instruction.arg1!).Second() + "\n"
                );
                port.Write(
                    indent + "    args: "
                    + Value.AsPair(instruction.arg1!).Fourth() + "\n"
                );
                WriteCode(
                    port,
                    (List<Instruction>) Value.AsPair(instruction.arg1!).Sixth(),
                    indent + "    "
                );
            }
            else
            {
                port.Write(
                    String.Format(
                        "{0}{1} {2}\n",
                        indent,
                        index + ":",
                        instruction.ToString(),
                        CultureInfo.InvariantCulture
                    )
                );
            }
            index++;
        }
    }
}
