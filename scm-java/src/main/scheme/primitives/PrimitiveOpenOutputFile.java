package scheme.primitives;

import scheme.*;

import java.io.*;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;

public class PrimitiveOpenOutputFile extends Primitive {
    @Override
    public String name() {
        return "open-output-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-output-file filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Takes a filename and returns a textual output port that writes characters to the named file. The file is created or truncated. It is an error if the file cannot be opened.\n" +
               "Example:\n" +
               "  (define p (open-output-file \"out.txt\"))\n" +
               "  (write-char #\\A p)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 4);
        String filename = new String(Value.asString(arguments[0]));
        try {
            Charset encoding = StandardCharsets.UTF_8;
            boolean append = false;
            boolean deflate = false;
            @SuppressWarnings("unused")
            boolean add_bom = false;
            for (var i = 1; i < arguments.length; i++) {
                String arg;
                if (Value.isSymbol(arguments[i])) {
                    arg = Value.asSymbol(arguments[i]);
                } else {
                    arg = new String(Value.asString(arguments[i]));
                }
                if (Encoding.isEncoding(arg)) {
                    encoding = Encoding.getEncoding(arg);
                    add_bom = arg.toLowerCase().equals("utf8bom") 
                        || arg.toLowerCase().equals("utf-8-bom");
                } else if (arg.equals("deflate")) {
                    deflate = true;
                } else if (arg.equals("append")) {
                    append = true;
                }
            }
            if (append) {
                if (deflate) {
                    return new TextOutputStream(new OutputStreamWriter(new DeflaterOutputStream(new FileOutputStream(filename, true), new Deflater(Deflater.DEFAULT_COMPRESSION, true)), encoding));
                } else {
                    // TODO handle BOM?
                    return new TextOutputStream(new OutputStreamWriter(new FileOutputStream(filename, true), encoding));
                }
            } else {
                if (deflate) {
                    return new TextOutputStream(new OutputStreamWriter(new DeflaterOutputStream(new FileOutputStream(filename), new Deflater(Deflater.DEFAULT_COMPRESSION, true)), encoding));
                } else {
                    // TODO handle BOM?
                    return new TextOutputStream(new OutputStreamWriter(new FileOutputStream(filename), encoding));
                }
            }
        } catch (Exception e) {
            throw new SchemeError(pos, new FileErrorObject("open-output-file: io failure", new Object[] { filename }));
        }
    }
}
