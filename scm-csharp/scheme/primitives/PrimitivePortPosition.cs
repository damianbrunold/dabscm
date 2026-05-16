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
            "Description: Returns the current position of the textual input port as a list (filename line column).\n" +
            "Example:\n" +
            "  (define p (open-input-string \"hello\"))\n" +
            "  (port-position p) => (\"{string}\" 1 1)";
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
	return new Pair(
	    port.Filename(),
	    new Pair(
		port.Line(),
		new Pair(
		    port.Column(),
		    Value.NIL)));
    }
}
