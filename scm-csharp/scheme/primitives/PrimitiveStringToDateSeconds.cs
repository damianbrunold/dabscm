using System.Globalization;

namespace scheme;

public class PrimitiveStringToDateSeconds : Primitive
{
    public override string Name()
    {
        return "string->date-seconds";
    }

    public override string Info()
    {
        return
            "Syntax: (string->date-seconds s format?)\n" +
            "Library: (scm string)\n" +
            "Description: Parses the date/time string s (in formats like yyyyMMddHHmmss, yyyyMMddHHmm, yyyyMMddHH, or yyyyMMdd) and returns the number of seconds since the Unix epoch. Returns #f if parsing fails.\n" +
            "Example:\n" +
            "  (string->date-seconds \"20240101120000\") => 1704110400\n" +
            "  (string->date-seconds \"invalid\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string s = new String(Value.AsString(arguments[0]));
        try
        {
            DateTimeStyles styles = DateTimeStyles.None;
            DateTime result;
            var fmt = "yyyyMMddHHmmss";
            DateTime.TryParseExact(s, fmt, null, styles, out result);
            if (result == DateTime.MinValue)
            {
                fmt = "yyyyMMddHHmm";
                DateTime.TryParseExact(s, fmt, null, styles, out result);
            }
            if (result == DateTime.MinValue)
            {
                fmt = "yyyyMMddHH";
                DateTime.TryParseExact(s, fmt, null, styles, out result);
            }
            if (result == DateTime.MinValue)
            {
                fmt = "yyyyMMdd";
                DateTime.TryParseExact(s, fmt, null, styles, out result);
            }
            if (result == DateTime.MinValue) return Value.F;
            return (long) (result - DateTime.UnixEpoch).TotalSeconds;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
