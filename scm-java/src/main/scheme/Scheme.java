package scheme;

import scheme.primitives.PrimitiveRead;
import scheme.primitives.PrimitiveDisassemble;
import scheme.repl.History;
import scheme.repl.LineEditor;
import scheme.repl.SchemeCompletionProvider;
import scheme.repl.Terminal;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class Scheme implements IEvaluator {

    // Store command-line args for command-line primitive
    public static String[] commandLineArgs = new String[0];
    public static boolean strictImports = false;

    private Modules modules;
    private Compiler compiler;
    private VM vm;

    public static Scheme forRepl() throws IOException {
        var scheme = new Scheme();
        scheme.setupUserMainModule();
        return scheme;
    }

    public static Scheme forMinimal() throws IOException {
        var scheme = new Scheme();
        scheme.setupUserMinimalModule();
        return scheme;
    }

    public static Scheme forProgram() throws IOException {
        var scheme = new Scheme();
        scheme.setupUserProgramModule();
        return scheme;
    }

    public static Scheme forSysadmin() throws IOException {
        var scheme = new Scheme();
        scheme.setupUserSysadminModule();
        return scheme;
    }
        
    public Scheme() throws IOException {
        this.modules = new Modules();
        this.compiler = new Compiler(modules);
        this.vm = new VM(modules);
        this.modules.evaluator = this;
        // populate (scm core) — library.scm handles its own exports
        loadLibraries();
    }

    public Scheme(Modules modules) throws IOException {
        this.modules = modules;
        compiler = new Compiler(modules);
        vm = new VM(modules);
        this.modules.evaluator = this;
    }

    public void dumpCallCounts() {
        // TODO
    }

    public void snapshot() {
        modules.takeSnapshot();
    }

    public void reset() {
        if (modules.hasSnapshot()) {
            modules.restoreFromSnapshot();
            return;
        }
        if (this.modules.hasModule("user sysadmin")) {
            modules.resetModules();
            setupUserSysadminModule();
        } else if (this.modules.hasModule("user main")) {
            modules.resetModules();
            setupUserMainModule();
        } else if (this.modules.hasModule("user minimal")) {
            modules.resetModules();
            setupUserMinimalModule();
        } else {
            modules.resetModules();
            setupUserProgramModule();
        }
    }

    public Object read(TextStream reader) {
        PrimitiveRead read = (PrimitiveRead) modules.getModuleRequired(reader.pos(), "scm core").resolve(reader.pos(), "read");
        return read.apply(reader.pos(), new Object[] { reader });
    }

    public void bind(String name, Object value) {
        modules.getCurrentModule().bind(name, value);
    }

    public boolean isDebug(SourcePos pos, String what) {
        what = Value.intern(what);
        var scm_core = this.modules.getModuleRequired(pos, "scm core");
        if (scm_core.isBound("*debug*")) {
            var dbg = scm_core.resolve(pos, "*debug*");
            if (Value.isPair(dbg)) {
                Object lst = Value.asPair(dbg);
                while (lst != Value.NIL) {
                    var lstPair = Value.asPair(lst);
                    if (Value.asSymbol(lstPair.car).equals(what)) return true;
                    lst = lstPair.cdr;
                }
            }
        }
        return false;
    }
    
    public void debug(SourcePos pos, String what, String message) {
        if (isDebug(pos, what)) {
            System.out.println("DEBUG: " + message);
        }
    }
    
    @SuppressWarnings("unchecked")
    public Object eval(SourcePos pos, Object expr) {
        Pair fn = compiler.compile(pos, expr);
        Object env = fn.second();
        List<Instruction> instructions = (List<Instruction>) fn.sixth();
        Lambda lambda = new Lambda(env, instructions);
        lambda.name = "<toplevel>";

        if (isDebug(pos, "compile")) {
            new PrimitiveDisassemble(modules).apply(pos, new Object[] { lambda });
        }

        return vm.execute(lambda);
    }

    public Object eval(Object expr) {
        return eval(null, expr);
    }

    public Object evalString(String string, String fname) {
        return evalFile(new TextStream(new PushbackReader(new StringReader(string)), fname), fname);
    }

    public Object evalFile(File file) {
        try {
            return evalFile(new FileInputStream(file), file.getPath());
        } catch (SchemeError e) {
            throw e;
        } catch (java.io.IOException e) {
            throw new SchemeError("Cannot evaluate file ~a: io error", file.getPath());
        } catch (Exception e) {
            throw new SchemeError("Cannot evaluate file ~a: internal error", file.getPath());
        }
    }

    public Object evalFile(InputStream stream, String fname) {
        return evalFile(new TextStream(new PushbackReader(new InputStreamReader(stream, StandardCharsets.UTF_8)), fname), fname);
    }

    public Object evalFile(TextStream reader, String fname) {
        var pos = reader.pos();
        Object expr = read(reader);
        Object value = Value.F;
        while (expr != Value.EOF) {
            value = eval(pos, expr);
            pos = reader.pos();
            expr = read(reader);
        }
        return value;
    }

    public void setupUserMainModule() {
        var user_main = new Module("user main");
        modules.setCurrentModule("user main");
        var libs = new String[] {
            "(scheme base)",
            "(scheme file)",
            "(scheme process-context)",
            "(scheme read)",
            "(scheme time)",
            "(scheme write)",
            "(scm fs)",
            "(scm io)",
            "(scm list)",
            "(scm string)",
            "(scm doc)",
            "(srfi 13)"
        };
        for (var lib : libs) {
            evalString("(import " + lib + ")", lib);
        }
        modules.updateModuleVar();
        modules.setCurrentModule("user main");
    }
    
    public void setupUserMinimalModule() {
        var user_minimal = new Module("user minimal");
        modules.setCurrentModule("user minimal");
        evalString("(import (scheme base))", "(scheme base)");
        evalString("(import (scheme write))", "(scheme write)");
        modules.updateModuleVar();
        modules.setCurrentModule("user minimal");
    }

    public void setupUserProgramModule() {
        var scm_core = modules.getModuleRequired(null, "scm core");
        modules.setCurrentModule("user program");
    }

    public void setupUserSysadminModule() {
        var user_sysadmin = new Module("user sysadmin");
        modules.setCurrentModule("user sysadmin");
        var libs = new String[] {
            "(scheme base)",
            "(scheme file)",
            "(scheme process-context)",
            "(scheme read)",
            "(scheme time)",
            "(scheme write)",
            "(scm sysadmin)",
            "(scm io)",
            "(scm glob)",
            "(scm string)",
            "(scm doc)",
            "(srfi 1)",
            "(srfi 13)"
        };
        for (var lib : libs) {
            evalString("(import " + lib + ")", lib);
        }
        modules.updateModuleVar();
        modules.setCurrentModule("user sysadmin");
    }

    public void loadLibraries() throws IOException {
        evalFile(new TextStream(new PushbackReader(new InputStreamReader(Scheme.class.getResourceAsStream("/library.scm"), StandardCharsets.UTF_8)), "library.scm"), "{library}");
    }

    public void flushOutputPorts() {
        try {
            var core = modules.getModuleRequired(null, "scm core");
            Object outPort = core.resolve("*output-port*");
            if (Value.isOutputPort(outPort)) {
                Value.asOutputPort(outPort).flush();
            }
            Object errPort = core.resolve("*error-port*");
            if (Value.isOutputPort(errPort)) {
                Value.asOutputPort(errPort).flush();
            }
        } catch (Exception ignored) {
        }
    }

    public void repl() throws IOException {
        boolean interactive = System.console() != null;
        Terminal term = interactive ? new Terminal() : null;
        if (interactive && term.canRaw()) {
            interactiveRepl(term);
            return;
        }
        // Cooked fallback: redirected stdin, dumb terminals, Windows, etc.
        if (interactive) { System.out.print("> "); System.out.flush(); }
        TextStream in = new TextStream(new PushbackReader(new InputStreamReader(System.in)), "{stdin}");
        while (true) {
            try {
                Object expr = read(in);
                if (expr == Value.EOF) break;
                Object value = eval(expr);
                flushOutputPorts();
                System.out.println(Value.printRep(value));
            } catch (SchemeError e) {
                e.printStackTrace();
            }
            if (interactive) { System.out.print("> "); System.out.flush(); }
        }
    }

    private void interactiveRepl(Terminal term) throws IOException {
        Path histFile = historyPath();
        History history = new History(histFile);
        SchemeCompletionProvider provider = new SchemeCompletionProvider(this);
        LineEditor editor = new LineEditor(term, history, provider);
        try {
            term.enterRaw();
            while (true) {
                String input;
                try {
                    input = editor.readSexp("> ");
                } catch (IOException eof) {
                    if ("EOF".equals(eof.getMessage())) break;
                    throw eof;
                }
                if (input == null || input.trim().isEmpty()) continue;
                // Drop raw mode while the user expression runs so its own I/O
                // behaves normally (line buffering, signal delivery, etc.).
                term.restore();
                try {
                    Object v = evalString(input, "{stdin}");
                    flushOutputPorts();
                    System.out.println(Value.printRep(v));
                } catch (SchemeError e) {
                    e.printStackTrace();
                    flushOutputPorts();
                } finally {
                    term.enterRaw();
                }
            }
        } finally {
            term.restore();
        }
    }

    private static Path historyPath() {
        String custom = System.getenv("DABSCM_HISTORY");
        if (custom != null && !custom.isEmpty()) return Paths.get(custom);
        String home = System.getProperty("user.home");
        if (home == null) return null;
        return Paths.get(home, ".dabscm-history");
    }

    public static void main(String... args) throws IOException {
        List<String> filteredArgs = new ArrayList<>();
        boolean sysadmin = false;
        for (String arg : args) {
            if (arg.equals("--strict")) {
                strictImports = true;
            } else if (arg.equals("--sysadmin")) {
                sysadmin = true;
            } else {
                filteredArgs.add(arg);
            }
        }
        args = filteredArgs.toArray(new String[0]);
        commandLineArgs = args;
        if (args.length > 0 && (args[0].equals("--version") || args[0].equals("-v"))) {
            try (var stream = Scheme.class.getResourceAsStream("/version.txt")) {
                String version = stream != null ? new String(stream.readAllBytes()).trim() : "unknown";
                System.out.println(version);
            } catch (Exception e) {
                System.out.println("unknown");
            }
            System.out.flush();
            return;
        }
        if (args.length >= 2 && args[0].equals("-e")) {
            Scheme scheme = null;
            try {
                scheme = Scheme.forMinimal();
                var result = scheme.evalString(args[1], "{-e}");
                System.out.println(Value.printRep(result));
            } catch (SchemeError e) {
                e.printStackTrace();
                if (scheme != null) scheme.flushOutputPorts();
                System.out.flush();
                System.exit(1);
            }
            if (scheme != null) scheme.flushOutputPorts();
            System.out.flush();
            return;
        } else if (args.length >= 2 && args[0].equals("-b")) {
            Scheme scheme = null;
            try {
                scheme = Scheme.forProgram();
                var result = scheme.evalString(args[1], "{-b}");
                System.out.println(Value.printRep(result));
            } catch (SchemeError e) {
                e.printStackTrace();
                if (scheme != null) scheme.flushOutputPorts();
                System.out.flush();
                System.exit(1);
            }
            if (scheme != null) scheme.flushOutputPorts();
            System.out.flush();
            return;
        } else if (args.length >= 2 && args[0].equals("-f")) {
            Scheme scheme = null;
            try {
                scheme = Scheme.forRepl();
                var result = scheme.evalString(args[1], "{-f}");
                System.out.println(Value.printRep(result));
            } catch (SchemeError e) {
                e.printStackTrace();
                if (scheme != null) scheme.flushOutputPorts();
                System.out.flush();
                System.exit(1);
            }
            if (scheme != null) scheme.flushOutputPorts();
            System.out.flush();
            return;
        } else if (args.length == 1 &&
                   (args[0].equals("-e") || args[0].equals("-b") || args[0].equals("-f"))) {
            try {
                Scheme scheme;
                if (args[0].equals("-e")) scheme = Scheme.forMinimal();
                else if (args[0].equals("-b")) scheme = Scheme.forProgram();
                else scheme = Scheme.forRepl();
                scheme.repl();
                scheme.flushOutputPorts();
            } catch (SchemeError e) {
                e.printStackTrace();
            }
        } else if (args.length > 0) {
            Scheme scheme = null;
            try {
                scheme = sysadmin ? Scheme.forSysadmin() : Scheme.forProgram();
                var script = args[0];
                Object arguments = Value.NIL;
                for (var i = args.length - 1; i >= 1; i--) {
                    arguments = new Pair(args[i].toCharArray(), arguments);
                }
                scheme.bind("script-name", script.toCharArray());
                scheme.bind("script-arguments", arguments);
                var result = scheme.evalFile(new File(script));
                if (Value.isInteger(result)) {
                    scheme.flushOutputPorts();
                    System.out.flush();
                    System.exit(IntegerMath.toInt(result));
                }
            } catch (SchemeError e) {
                e.printStackTrace();
                if (scheme != null) scheme.flushOutputPorts();
                System.out.flush();
                System.exit(1);
            }
            if (scheme != null) scheme.flushOutputPorts();
        } else {
            try {
                var scheme = sysadmin ? Scheme.forSysadmin() : Scheme.forRepl();
                scheme.repl();
                scheme.flushOutputPorts();
            } catch (SchemeError e) {
                e.printStackTrace();
            }
        }
        System.out.flush();
    }
}
