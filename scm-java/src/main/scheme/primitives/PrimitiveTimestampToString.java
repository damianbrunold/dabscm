package scheme.primitives;

import scheme.*;

import java.text.*;
import java.util.Date;

public class PrimitiveTimestampToString extends Primitive {
    @Override
    public String name() {
        return "timestamp->string";
    }

    @Override
    public String info() {
        return "Syntax: (timestamp->string ms format?)\n" +
               "Library: (scm datetime)\n" +
               "Description: Formats a timestamp (milliseconds) as a date string. The optional format may be isodatetime, isodate, datetime, date, or a custom .NET format string; defaults to isodatetime.\n" +
               "Example:\n" +
               "  (timestamp->string (timestamp)) => \"20260318-153045\"\n" +
               "  (timestamp->string (timestamp) 'isodate) => \"20260318\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        var ts = IntegerMath.toLong(arguments[0]);
        var fmt = "isodatetime";
        if (arguments.length > 1) {
            if (Value.isSymbol(arguments[1])) {
                fmt = Value.asSymbol(arguments[1]);
            } else {
                fmt = new String(Value.asString(arguments[1]));
            }
        }
        DateFormat format;
        if (fmt.equals("isodatetime")) {
            format = new SimpleDateFormat("yyyyMMdd-HHmmss");
        } else if (fmt.equals("isodatetime2")) {
            format = new SimpleDateFormat("yyyyMMdd HHmmss");
        } else if (fmt.equals("isodate")) {
            format = new SimpleDateFormat("yyyyMMdd");
        } else if (fmt.equals("isodate-hours")) {
            format = new SimpleDateFormat("yyyyMMddHH");
        } else if (fmt.equals("datetime")) {
            format = new SimpleDateFormat("dd.MM.yyyy HH:mm:ss");
        } else if (fmt.equals("date")) {
            format = new SimpleDateFormat("dd.MM.yyyy");
        } else {
            format = new SimpleDateFormat(fmt);
        }
        return format.format(new Date(ts)).toCharArray();
    }
}
