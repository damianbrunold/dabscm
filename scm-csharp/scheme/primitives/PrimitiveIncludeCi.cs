using System.Text;

namespace scheme;

public class PrimitiveIncludeCi : Primitive
{
    private Modules modules;

    public PrimitiveIncludeCi(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name() => "include-ci";

    public override string Info() =>
        "Syntax: (include-ci filename ...)\n" +
        "Library: (scheme base)\n" +
        "Description: Like include, but reads the files in case-insensitive mode (all identifiers are folded to lowercase).\n" +
        "Example:\n" +
        "  (include-ci \"legacy.scm\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        try
        {
            Scheme scheme = new Scheme(modules);
            for (int i = 0; i < arguments.Length; i++)
            {
                string filename = new string(Value.AsString(arguments[i]));
                using var reader = new StreamReader(new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.UTF8);
                using var stream = new TextStream(reader, filename);
                stream.FoldCase = true;
                scheme.EvalFile(stream, filename);
            }
            return new Values();
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, Name() + ": io failure");
        }
    }
}
