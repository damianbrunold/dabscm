package scheme.primitives;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.PushbackReader;
import java.nio.charset.StandardCharsets;

import scheme.Modules;
import scheme.Primitive;
import scheme.Scheme;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.TextStream;
import scheme.Value;
import scheme.Values;

public class PrimitiveIncludeCi extends Primitive {
    private Modules modules;

    public PrimitiveIncludeCi(Modules modules) {
        this.modules = modules;
    }

    @Override
    public String name() {
        return "include-ci";
    }

    @Override
    public String info() {
        return "Syntax: (include-ci filename ...)\n" +
               "Library: (scheme base)\n" +
               "Description: Like include, but reads the files in case-insensitive mode (all identifiers are folded to lowercase).\n" +
               "Example:\n" +
               "  (include-ci \"legacy.scm\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, -1);
        try {
            Scheme scheme = new Scheme(modules);
            for (var i = 0; i < arguments.length; i++) {
                String filename = new String(Value.asString(arguments[i]));
                var stream = new TextStream(new PushbackReader(new InputStreamReader(new FileInputStream(new File(filename)), StandardCharsets.UTF_8)), filename);
                stream.foldCase = true;
                scheme.evalFile(stream, filename);
            }
            return new Values();
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure");
        }
    }
}
