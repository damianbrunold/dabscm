using System.Globalization;
using System.Text;

namespace scheme;

public class SchemeError : Exception
{
    public SourcePos? pos;
    public SchemeError? parent;
    public ErrorObject? errorObject;
    public List<SchemeCallFrame>? schemeCallStack;

    public SchemeError(SourcePos? pos, ErrorObject errorObject)
        : this(null, pos, errorObject.ToString())
    {
        this.errorObject = errorObject;
    }

    public SchemeError(string message, params Object[] values)
	: this(null, null, message, values)
    {
    }
	
    public SchemeError(SchemeError? parent,
                       string message, params Object[] values)
	: this(parent, null, message, values)
    {
    }
	
    public SchemeError(SourcePos? pos,
                       string message, params Object[] values)
        : this(null, pos,  message, values)
    {
    }
    
    public SchemeError(SchemeError? parent, SourcePos? pos,
                       string message, params Object[] values)
        : base(FmtMessage(message, values), parent)
    {
        this.pos = pos;
        this.parent = parent;
    }
    
    private static string FmtMessage(string message, Object[] values)
    {
        var result = new StringBuilder();
        var idx = 0;
        while (message != "")
        {
            var p = message.IndexOf("~s");
            if (p == -1)
            {
                p = message.IndexOf("~a");
                if (p == -1)
                {
                    result.Append(message);
                    message = "";
                }
                else
                {
                    result.Append(message.Substring(0, p));
                    message = message.Substring(p+2);
                    result.Append(Value.DisplayRep(values[idx]));
                    idx++;
                }
            }
            else
            {
                result.Append(message.Substring(0, p));
                message = message.Substring(p+2);
                result.Append(Value.PrintRep(values[idx]));
                idx++;
            }
        }
        return result.ToString();
    }

    public void PrintStackTrace()
    {
        PrintStackTrace(Console.Out);
    }

    public void PrintStackTrace(TextWriter writer)
    {
        writer.WriteLine(ToString());
        if (schemeCallStack != null && schemeCallStack.Count > 0)
        {
            // Filter out internal frames with no source position
            var meaningful = schemeCallStack
                .Where(f => !(f.name != null && f.name.StartsWith("<") && f.pos == null))
                .ToList();
            if (meaningful.Count > 0)
            {
                writer.WriteLine("Scheme call stack:");
                foreach (var frame in meaningful)
                {
                    writer.WriteLine(frame.ToString());
                }
            }
        }
        if (parent != null)
        {
            writer.WriteLine("caused by:");
            parent.PrintStackTrace(writer);
        }
    }
    
    public override string ToString()
    {
	if (pos != null) {
	    return Message + " (" + pos + ")";
	}
	else
	{
	    return Message;
	}
    }
}
