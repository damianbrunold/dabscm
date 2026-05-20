package scheme.repl;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import scheme.Pair;
import scheme.Scheme;
import scheme.Value;

/**
 * Bridges the line editor to the Scheme {@code (scm repl)} library. All
 * calls are wrapped in try/catch — a broken user definition of these
 * names must never kill the editor.
 */
public final class SchemeCompletionProvider implements CompletionProvider {

    private final Scheme scheme;
    private boolean enabled = true;

    public SchemeCompletionProvider(Scheme scheme) {
        this.scheme = scheme;
        // Best-effort: import the library. If it fails (e.g. minimal env), we
        // simply disable completion.
        try {
            scheme.evalString("(import (scm repl))", "<repl-bootstrap>");
        } catch (Throwable t) {
            enabled = false;
        }
    }

    @Override
    public List<String> completions(String prefix) {
        if (!enabled || prefix == null) return Collections.emptyList();
        try {
            scheme.bind("__repl-arg", prefix.toCharArray());
            Object result = scheme.evalString("(repl-completions __repl-arg)", "<repl-tab>");
            return asStringList(result);
        } catch (Throwable t) {
            return Collections.emptyList();
        }
    }

    @Override
    public String infoLine(String name) {
        if (!enabled || name == null || name.isEmpty()) return "";
        try {
            scheme.bind("__repl-arg", name.toCharArray());
            Object result = scheme.evalString("(repl-info-line __repl-arg)", "<repl-info>");
            return asString(result);
        } catch (Throwable t) {
            return "";
        }
    }

    private static List<String> asStringList(Object o) {
        List<String> out = new ArrayList<>();
        while (o instanceof Pair) {
            Pair p = (Pair) o;
            String s = asString(p.car);
            if (s != null) out.add(s);
            o = p.cdr;
        }
        return out;
    }

    private static String asString(Object o) {
        if (o == null) return "";
        if (o instanceof char[]) return new String((char[]) o);
        if (o instanceof String) return (String) o;
        return Value.printRep(o);
    }
}
