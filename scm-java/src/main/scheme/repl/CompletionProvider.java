package scheme.repl;

import java.util.List;

/** Bridge between the line editor and the Scheme {@code (scm repl)} module. */
public interface CompletionProvider {
    /** Names that complete the given prefix; never null. */
    List<String> completions(String prefix);
    /** One-line info string for the symbol at the cursor; empty when unknown. */
    String infoLine(String name);
}
