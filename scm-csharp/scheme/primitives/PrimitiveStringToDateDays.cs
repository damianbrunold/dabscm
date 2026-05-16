using System.Globalization;

namespace scheme;

public class PrimitiveStringToDateDays : Primitive
{
    public override string Name()
    {
        return "string->date-days";
    }

    public override string Info()
    {
        return
            "Syntax: (string->date-days s format?)\n" +
            "Library: (scm string)\n" +
            "Description: Parses the date string s in yyyyMMdd format and returns the number of days since the OLE Automation epoch (December 30, 1899). Returns #f if parsing fails.\n" +
            "Example:\n" +
            "  (string->date-days \"20240101\") => 45292\n" +
            "  (string->date-days \"invalid\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string s = new String(Value.AsString(arguments[0]));
        try
        {
            if (s.Length > 8) s = s.Substring(0, 8);
            var fmt = "yyyyMMdd";
            DateTime result;
            DateTime.TryParseExact(s, fmt, null, DateTimeStyles.None, out result);
            if (result == DateTime.MinValue) return Value.F;
            return (long) result.ToOADate();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
