package scheme.primitives;

import scheme.*;

import java.util.concurrent.TimeUnit;
import java.text.*;
import java.util.Date;
import java.util.TimeZone;

public class PrimitiveStringToDateDays extends Primitive {
    @Override
    public String name() {
        return "string->date-days";
    }

    @Override
    public String info() {
        return "Syntax: (string->date-days s format?)\n" +
               "Library: (scm datetime)\n" +
               "Description: Parses the date string s in yyyyMMdd format and returns the number of days since the OLE Automation epoch (December 30, 1899). Returns #f if parsing fails.\n" +
               "Example:\n" +
               "  (string->date-days \"20240101\") => 45292\n" +
               "  (string->date-days \"invalid\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String s = new String(Value.asString(arguments[0]));
        try {
            if (s.length() > 8) s = s.substring(0, 8);
            DateFormat fmt = new SimpleDateFormat("yyyyMMdd");
            fmt.setTimeZone(TimeZone.getTimeZone("UTC"));
            Date date = fmt.parse(s);
            long unixDays = TimeUnit.DAYS.convert(date.getTime(), TimeUnit.MILLISECONDS);
            return unixDays + 25569L;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
