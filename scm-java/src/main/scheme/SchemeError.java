package scheme;

public class SchemeError extends RuntimeException {
    public SourcePos pos;
    public SchemeError parent;
    public ErrorObject errorObject;
    public java.util.List<SchemeCallFrame> schemeCallStack;

    public SchemeError(SourcePos pos, ErrorObject errorObject) {
        super(errorObject.toString());
        this.pos = pos;
        this.errorObject = errorObject;
    }

    public SchemeError(String message, Object... values) {
        super(fmt(message, values));
    }
	
    public SchemeError(SchemeError parent, String message, Object... values) {
        super(fmt(message, values), parent);
        this.parent = parent;
    }

    public SchemeError(SourcePos pos, String message, Object... values) {
        super(fmt(message, values));
        this.pos = pos;
    }

    public SchemeError(SourcePos pos, SchemeError parent, String message, Object... values) {
        super(fmt(message, values), parent);
        this.pos = pos;
        this.parent = parent;
    }

    public SchemeError(SchemeError parent, SourcePos pos, String message, Object... values) {
        super(fmt(message, values), parent);
        this.pos = pos;
        this.parent = parent;
    }

    private static String fmt(String message, Object... values) {
        StringBuilder result = new StringBuilder();
        int idx = 0;
        while (!message.isEmpty()) {
            var ps = message.indexOf("~s");
            var pa = message.indexOf("~a");
            if (ps == -1 && pa == -1) {
                result.append(message);
                message = "";
            } else if (pa == -1 || (ps != -1 && ps <= pa)) {
                result.append(message.substring(0, ps));
                message = message.substring(ps + 2);
                result.append(Value.printRep(values[idx]));
                idx++;
            } else {
                result.append(message.substring(0, pa));
                message = message.substring(pa + 2);
                result.append(Value.displayRep(values[idx]));
                idx++;
            }
        }
        return result.toString();
    }

    public void printStackTrace()
    {
        printStackTrace(System.out);
    }

    @Override
    public void printStackTrace(java.io.PrintStream out)
    {
        out.println(toString());
        if (schemeCallStack != null && !schemeCallStack.isEmpty()) {
            // Filter out internal frames with no source position
            boolean hasMeaningful = false;
            for (var frame : schemeCallStack) {
                if (!(frame.name != null && frame.name.startsWith("<") && frame.pos == null)) {
                    hasMeaningful = true;
                    break;
                }
            }
            if (hasMeaningful) {
                out.println("Scheme call stack:");
                for (var frame : schemeCallStack) {
                    if (!(frame.name != null && frame.name.startsWith("<") && frame.pos == null)) {
                        out.println(frame.toString());
                    }
                }
            }
        }
        if (parent != null) {
            out.println("caused by:");
            parent.printStackTrace(out);
        }
    }

    @Override
    public void printStackTrace(java.io.PrintWriter out)
    {
        out.println(toString());
        if (schemeCallStack != null && !schemeCallStack.isEmpty()) {
            boolean hasMeaningful = false;
            for (var frame : schemeCallStack) {
                if (!(frame.name != null && frame.name.startsWith("<") && frame.pos == null)) {
                    hasMeaningful = true;
                    break;
                }
            }
            if (hasMeaningful) {
                out.println("Scheme call stack:");
                for (var frame : schemeCallStack) {
                    if (!(frame.name != null && frame.name.startsWith("<") && frame.pos == null)) {
                        out.println(frame.toString());
                    }
                }
            }
        }
        if (parent != null) {
            out.println("caused by:");
            parent.printStackTrace(out);
        }
    }
    
    @Override
    public String toString() {
        if (pos != null) return getMessage() + " (" + pos + ")";
        return getMessage();
    }
}
