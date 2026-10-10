using System.Text;

namespace scheme;

public class PrimitivePortPosition : Primitive
{
    private Modules modules;

    public PrimitivePortPosition(Modules modules)
    {
        this.modules = modules;
    }

    public override string Name()
    {
        return "port-position";
    }

    public override string Info()
    {
        return
            "Syntax: (port-position port)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the current position of the textual input port as a list (filename line column): line 1-based, column 0-based, filename \"{string}\" for string ports.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"hello\"))\n" +
            "  (port-position p) => (\"{string}\" 1 0)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        TextStream port;
        if (arguments.Length == 0)
        {
            var scmcore = modules.GetModuleRequired(pos, "scm core");
            port = Value.AsInputPort(scmcore.Resolve(pos, "*input-port*"));
        }
        else
        {
            port = Value.AsInputPort(arguments[0]);
        }
	// line/column as Scheme integers (long); string ports have no file
	// name and report "{string}"
	string? filename = port.Filename();
	return new Pair(
	    (filename ?? "{string}").ToCharArray(),
	    new Pair(
		(long) port.Line(),
		new Pair(
		    (long) port.Column(),
		    Value.NIL)));
    }
}
