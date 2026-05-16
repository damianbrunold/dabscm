package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveFileModificationTimestamp extends Primitive {
    @Override
    public String name() {
        return "file-modification-timestamp";
    }

    @Override
    public String info() {
        return "Syntax: (file-modification-timestamp filename)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the last modification time of the file as a millisecond timestamp (milliseconds since the .NET epoch).\n" +
               "Example:\n" +
               "  (file-modification-timestamp \"data.txt\") => 1700000000000";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var file = new File(new String(Value.asString(arguments[0])));
        return file.lastModified();
    }
}
