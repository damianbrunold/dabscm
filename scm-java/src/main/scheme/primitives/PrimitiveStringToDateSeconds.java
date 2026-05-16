package scheme.primitives;

import scheme.*;

import java.text.*;
import java.util.Date;
import java.util.TimeZone;

public class PrimitiveStringToDateSeconds extends Primitive {
    @Override
    public String name() {
        return "string->date-seconds";
    }

    @Override
    public String info() {
        return "Syntax: (string->date-seconds s format?)\n" +
               "Library: (scm string)\n" +
               "Description: Parses the date/time string s (in formats like yyyyMMddHHmmss, yyyyMMddHHmm, yyyyMMddHH, or yyyyMMdd) and returns the number of seconds since the Unix epoch. Returns #f if parsing fails.\n" +
               "Example:\n" +
               "  (string->date-seconds \"20240101120000\") => 1704110400\n" +
               "  (string->date-seconds \"invalid\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String s = new String(Value.asString(arguments[0]));
        try {
            Date date = null;
            if (date == null) {
                DateFormat fmt = new SimpleDateFormat("yyyyMMddHHmmss");
                fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
                try {
                    date = fmt.parse(s);
                } catch (ParseException e) {
                }
            }
            if (date == null) {
                DateFormat fmt = new SimpleDateFormat("yyyyMMddHHmm");
                fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
                try {
                    date = fmt.parse(s);
                } catch (ParseException e) {
                }
            }
            if (date == null) {
                DateFormat fmt = new SimpleDateFormat("yyyyMMddHH");
                fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
                try {
                    date = fmt.parse(s);
                } catch (ParseException e) {
                }
            }
            if (date == null) {
                DateFormat fmt = new SimpleDateFormat("yyyyMMdd");
                fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
                try {
                    date = fmt.parse(s);
                } catch (ParseException e) {
                }
            }
            if (date == null) {
                return Value.F;
            }
            return (long) date.getTime() / 1000;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
