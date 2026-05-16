package scheme;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.io.PushbackReader;
import java.io.StringReader;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class SchemeTests {

    // ----------------------------------------------------------------
    // Core runner: test-group/=> format with snapshot/restore
    // ----------------------------------------------------------------

    private static int[] runCoreTest(String filename) throws IOException {
        int tests = 0;
        int failures = 0;
        var failureOutput = new StringBuilder();

        Scheme.strictImports = true;
        Scheme scheme = Scheme.forProgram();

        var inputStream = SchemeTests.class.getResourceAsStream(filename);
        var content = new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
        inputStream.close();

        var stream = new TextStream(new PushbackReader(new StringReader(content)), filename);
        var preambleForms = new java.util.ArrayList<Object>();
        boolean snapshotTaken = false;

        Object firstForm = scheme.read(stream);
        scheme.eval(null, firstForm);
        preambleForms.add(firstForm);

        while (true) {
            Object form = scheme.read(stream);
            if (Value.isEOFObject(form)) break;
            if (!Value.isPair(form)) continue;

            Pair pair = Value.asPair(form);
            if (!"test-group".equals(pair.car)) {
                scheme.eval(null, form);
                preambleForms.add(form);
                continue;
            }

            if (!snapshotTaken) {
                scheme.snapshot();
                snapshotTaken = true;
            }

            Object body = pair.cdr;
            while (body != Value.NIL) {
                Object subform = Value.asPair(body).car;
                body = Value.asPair(body).cdr;

                if (Value.isPair(subform) && "=>".equals(Value.asPair(subform).car)) {
                    SourcePos assertPos = Value.asPair(subform).pos;
                    Object assertParts = Value.asPair(subform).cdr;
                    Object exprForm = Value.asPair(assertParts).car;
                    Object expectedForm = Value.asPair(Value.asPair(assertParts).cdr).car;

                    try {
                        tests++;
                        String actual = Value.printRep(scheme.eval(exprForm));
                        Object expectedValue = scheme.eval(expectedForm);
                        String expected;
                        if (Value.isString(expectedValue)) {
                            String s = new String(Value.asString(expectedValue));
                            expected = s.startsWith("#<") ? s : Value.printRep(expectedValue);
                        } else {
                            expected = Value.printRep(expectedValue);
                        }
                        if (!actual.equals(expected)) {
                            failures++;
                            String loc = assertPos != null ? " at " + assertPos.filename + ":" + assertPos.line : "";
                            failureOutput.append("  FAIL").append(loc).append("\n");
                            failureOutput.append("    code:     ").append(Value.printRep(exprForm)).append("\n");
                            failureOutput.append("    expected: ").append(expected).append("\n");
                            failureOutput.append("    actual:   ").append(actual).append("\n");
                        }
                    } catch (Exception e) {
                        failures++;
                        String loc = assertPos != null ? " at " + assertPos.filename + ":" + assertPos.line : "";
                        failureOutput.append("  FAIL").append(loc).append("\n");
                        failureOutput.append("    code:      ").append(Value.printRep(exprForm)).append("\n");
                        failureOutput.append("    exception: ").append(e.getMessage()).append("\n");
                    }
                } else {
                    scheme.eval(subform);
                }
            }

            scheme.reset();
            for (Object pf : preambleForms) scheme.eval(null, pf);
        }

        if (failureOutput.length() > 0) System.out.print(failureOutput);
        return new int[]{tests, failures};
    }

    // ----------------------------------------------------------------
    // Tests runner: evaluate file, it reports on its own
    // ----------------------------------------------------------------

    private static int[] runTestsTest(String resourceName, String displayName) throws IOException {
        var inputStream = SchemeTests.class.getResourceAsStream(resourceName);
        var content = new String(inputStream.readAllBytes(), StandardCharsets.UTF_8);
        inputStream.close();

        var total = 0;
        var failed = 0;

        Scheme.strictImports = true;
        Scheme scheme = Scheme.forProgram();
        scheme.evalString(content, displayName);
        total = (int) (long) Value.asInteger(scheme.evalString("(last-run-total-tests)", "scheme-tests"));
        failed = (int) (long) Value.asInteger(scheme.evalString("(last-run-failed-tests)", "scheme-tests"));

        return new int[]{total, failed};
    }

    // ----------------------------------------------------------------
    // Failure runner: output-comparison tests
    // ----------------------------------------------------------------

    private static int[] runFailureTests(String platform) throws IOException {
        File failuresDir = new File("test/failures");
        if (!failuresDir.exists()) return new int[]{0, 0};

        int tests = 0;
        int failures = 0;

        String[] files = failuresDir.list();
        if (files == null) return new int[]{0, 0};
        Arrays.sort(files);

        for (String file : files) {
            if (!file.startsWith("test") || !file.endsWith(".scm")) continue;
            tests++;

            String baseName = file.substring(0, file.length() - 4);
            // Look for platform-specific expected, then generic
            File expectedFile = new File(failuresDir, baseName + ".expected-" + platform);
            if (!expectedFile.exists())
                expectedFile = new File(failuresDir, baseName + ".expected");
            if (!expectedFile.exists()) {
                System.out.println("  " + file + " SKIP (no .expected file)");
                continue;
            }

            String content = new String(java.nio.file.Files.readAllBytes(
                new File(failuresDir, file).toPath()), StandardCharsets.UTF_8);
            String expectedOutput = new String(java.nio.file.Files.readAllBytes(
                expectedFile.toPath()), StandardCharsets.UTF_8);

            // Capture stdout during test
            PrintStream originalOut = System.out;
            var capturedOutput = new ByteArrayOutputStream();
            System.setOut(new PrintStream(capturedOutput, true, StandardCharsets.UTF_8));

            try {
                Scheme.strictImports = true;
                Scheme scheme = Scheme.forProgram();
                try {
                    scheme.evalString(content, file);
                } catch (SchemeError e) {
                    e.printStackTrace();
                }
            } finally {
                System.setOut(originalOut);
            }

            String actual = normalizeOutput(capturedOutput.toString(StandardCharsets.UTF_8));
            String expected = normalizeOutput(expectedOutput);

            if (actual.equals(expected)) {
                System.out.println("  " + file + " OK");
            } else {
                failures++;
                System.out.println("  " + file + " FAIL");
                System.out.println("    expected: " + expected.replace("\n", "\n              "));
                System.out.println("    actual:   " + actual.replace("\n", "\n              "));
            }
        }

        return new int[]{tests, failures};
    }

    private static String normalizeOutput(String s) {
        String[] lines = s.replace("\r\n", "\n").replace("\r", "\n").split("\n", -1);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < lines.length; i++) {
            if (i > 0) sb.append("\n");
            sb.append(lines[i].stripTrailing());
        }
        // Trim trailing newlines
        while (sb.length() > 0 && sb.charAt(sb.length() - 1) == '\n')
            sb.setLength(sb.length() - 1);
        return sb.toString();
    }

    // ----------------------------------------------------------------
    // Main: run categories in order, with command-line filtering
    // ----------------------------------------------------------------

    public static void main(String[] args) throws IOException {
        boolean success = true;
        int grandTotalTests = 0;
        int grandTotalFailures = 0;

        // Parse command line
        Set<String> requestedCategories = new HashSet<>();
        Set<String> requestedSuites = new HashSet<>();
        boolean runAll = args.length == 0;

        for (String arg : args) {
            if (arg.contains(":")) {
                requestedCategories.add(arg.split(":")[0]);
                requestedSuites.add(arg.split(":")[1]);
            } else if (arg.equals("core") || arg.equals("tests") || arg.equals("failures"))
                requestedCategories.add(arg);
            else
                requestedSuites.add(arg);
        }

        // === core ===
        if (runAll || requestedCategories.contains("core") || !requestedSuites.isEmpty()) {
            System.out.println("=== core ===");
            int catTests = 0, catFailures = 0;
            File coreDir = new File("test/core");
            if (coreDir.exists()) {
                String[] files = coreDir.list();
                Arrays.sort(files);
                for (String file : files) {
                    if (!file.endsWith(".scm")) continue;
                    if (!runAll && !requestedSuites.isEmpty() && !requestedSuites.contains(file)
                        && !requestedSuites.contains(file.replace(".scm", ""))) continue;
                    if (!runAll && requestedSuites.isEmpty() && !requestedCategories.contains("core")) continue;

                    System.out.print("  " + file + " ");
                    try {
                        int[] result = runCoreTest("/core/" + file);
                        catTests += result[0];
                        catFailures += result[1];
                        if (result[1] == 0)
                            System.out.println("OK, " + result[0] + " tests");
                        else {
                            System.out.println("FAIL, " + result[0] + " tests, " + result[1] + " failed");
                            success = false;
                        }
                    } catch (SchemeError e) {
                        System.out.println("ERROR");
                        e.printStackTrace(System.out);
                        success = false;
                    } catch (Exception e) {
                        System.out.println("ERROR: " + e.getClass().getSimpleName() + ": " + e.getMessage());
                        e.printStackTrace(System.out);
                        success = false;
                    }
                }
            }
            System.out.println("  core: " + catTests + " tests, " + catFailures + " failures");
            System.out.println();
            grandTotalTests += catTests;
            grandTotalFailures += catFailures;
        }

        // === tests ===
        if (runAll || requestedCategories.contains("tests") || !requestedSuites.isEmpty()) {
            System.out.println("=== tests ===");
            int catTests = 0, catFailures = 0;
            File testsDir = new File("test/tests");
            if (testsDir.exists()) {
                String[] files = testsDir.list();
                Arrays.sort(files);
                for (String file : files) {
                    if (!file.endsWith(".scm")) continue;
                    if (!runAll && !requestedSuites.isEmpty() && !requestedSuites.contains(file)
                        && !requestedSuites.contains(file.replace(".scm", ""))) continue;
                    if (!runAll && requestedSuites.isEmpty() && !requestedCategories.contains("tests")) continue;

                    try {
                        // Tests category always uses SRFI-64 runner
                        int[] result = runTestsTest("/tests/" + file, file);

                        catTests += result[0];
                        catFailures += result[1];
                        if (result[1] > 0) {
                            success = false;
                        }
                    } catch (SchemeError e) {
                        System.out.println("ERROR");
                        e.printStackTrace(System.out);
                        success = false;
                    } catch (Exception e) {
                        System.out.println("ERROR: " + e.getClass().getSimpleName() + ": " + e.getMessage());
                        e.printStackTrace(System.out);
                        success = false;
                    }
                }
            }
            System.out.println("  tests: " + catTests + " tests, " + catFailures + " failures");
            System.out.println();
            grandTotalTests += catTests;
            grandTotalFailures += catFailures;
        }

        // === failures ===
        if (runAll || requestedCategories.contains("failures")) {
            System.out.println("=== failures ===");
            int[] result = runFailureTests("java");
            grandTotalTests += result[0];
            grandTotalFailures += result[1];
            if (result[1] > 0) success = false;
            System.out.println("  failures: " + result[0] + " tests, " + result[1] + " failures");
            System.out.println();
        }

        // === total ===
        System.out.println("=== total ===");
        if (success)
            System.out.println(grandTotalTests + " tests, 0 failures");
        else
            System.out.println(grandTotalTests + " tests, " + grandTotalFailures + " failures");

        System.exit(success ? 0 : 1);
    }
}
