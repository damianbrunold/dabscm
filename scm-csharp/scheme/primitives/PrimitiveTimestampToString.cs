using System.Globalization;

namespace scheme;

public class PrimitiveTimestampToString : Primitive
{
    public override string Name()
    {
        return "timestamp->string";
    }

    public override string Info()
    {
        return
            "Syntax: (timestamp->string ms format?)\n" +
            "Library: (scm datetime)\n" +
            "Description: Formats a timestamp (milliseconds) as a date string. The optional format may be isodatetime, isodate, datetime, date, or a custom .NET format string; defaults to isodatetime.\n" +
            "Example:\n" +
            "  (timestamp->string (timestamp)) => \"20260318-153045\"\n" +
            "  (timestamp->string (timestamp) 'isodate) => \"20260318\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        var ts = IntegerMath.ToLong(arguments[0]);
        var fmt = "isodatetime";
        if (arguments.Length > 1)
        {
            if (Value.IsSymbol(arguments[1]))
            {
                fmt = Value.AsSymbol(arguments[1]);
            }
            else
            {
                fmt = new String(Value.AsString(arguments[1]));
            }
        }
        var datetime = DateTimeOffset.FromUnixTimeMilliseconds(ts).LocalDateTime;
        if (fmt.Equals("isodatetime"))
        {
            return datetime.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture).ToCharArray();
        }
        if (fmt.Equals("isodatetime2"))
        {
            return datetime.ToString("yyyyMMdd HHmmss", CultureInfo.InvariantCulture).ToCharArray();
        }
        else if (fmt.Equals("isodate"))
        {
            return datetime.ToString("yyyyMMdd", CultureInfo.InvariantCulture).ToCharArray();
        }
        else if (fmt.Equals("isodate-hours"))
        {
            return datetime.ToString("yyyyMMddHH", CultureInfo.InvariantCulture).ToCharArray();
        }
        else if (fmt.Equals("datetime"))
        {
            return datetime.ToString("dd.MM.yyyy HH:mm:ss", CultureInfo.InvariantCulture).ToCharArray();
        }
        else if (fmt.Equals("date"))
        {
            return datetime.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture).ToCharArray();
        }
        else
        {
            return datetime.ToString(fmt, CultureInfo.InvariantCulture).ToCharArray();
        }
    }
}
