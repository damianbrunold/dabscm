package scheme.primitives;

import scheme.*;

import java.io.File;

public class PrimitiveDeleteFile extends Primitive {
    @Override
    public String name() {
        return "delete-file";
    }

    @Override
    public String info() {
        return "Syntax: (delete-file filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Deletes the named file. Returns unspecified if successful, #f if the file could not be deleted.\n" +
               "Example:\n" +
               "  (delete-file \"temp.txt\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var file = new File(new String(Value.asString(arguments[0])));
        try {
            if (!file.exists())
                throw new SchemeError(pos, new FileErrorObject("delete-file: file does not exist: " + file, new Object[] { Value.asString(arguments[0]) }));
            file.delete();
            return new Values();
        } catch (SchemeError e) { throw e; }
        catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("delete-file: " + e.getMessage(), new Object[] { Value.asString(arguments[0]) }));
        }
    }
}
