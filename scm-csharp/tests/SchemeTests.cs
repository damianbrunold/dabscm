using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using scheme;

namespace schemetests;

public class SchemeTests
{
    // ----------------------------------------------------------------
    // Core runner: test-group/=> format with snapshot/restore
    // ----------------------------------------------------------------

    private static (int tests, int failures, string details) RunCoreTest(string resourceName, string displayName)
    {
        int tests = 0;
        int failures = 0;
        var failureOutput = new StringBuilder();
        Scheme.StrictImports = true;
        Scheme scheme = Scheme.ForProgram();

        var assembly = typeof(SchemeTests).Assembly;
        var content = new StreamReader(
            assembly.GetManifestResourceStream(resourceName)!
        ).ReadToEnd();

        using var stream = new TextStream(new StringReader(content), displayName);
        var preambleForms = new List<object>();
        bool snapshotTaken = false;

        var firstForm = scheme.Read(stream);
        scheme.Eval(null, firstForm);
        preambleForms.Add(firstForm);

        while (true)
        {
            var form = scheme.Read(stream);
            if (Value.IsEOFObject(form)) break;
            if (!Value.IsPair(form)) continue;

            var pair = Value.AsPair(form);
            if (!pair.car.Equals("test-group"))
            {
                scheme.Eval(null, form);
                preambleForms.Add(form);
                continue;
            }

            if (!snapshotTaken)
            {
                scheme.Snapshot();
                snapshotTaken = true;
            }

            var body = pair.cdr;
            while (body != Value.NIL)
            {
                var subform = Value.AsPair(body).car;
                body = Value.AsPair(body).cdr;

                if (Value.IsPair(subform) && Value.AsPair(subform).car.Equals("=>"))
                {
                    var assertPos = Value.AsPair(subform).pos;
                    var assertParts = Value.AsPair(subform).cdr;
                    var exprForm = Value.AsPair(assertParts).car;
                    var expectedForm = Value.AsPair(Value.AsPair(assertParts).cdr).car;

                    try
                    {
                        tests++;
                        var actual = Value.PrintRep(scheme.Eval(exprForm));
                        var expectedValue = scheme.Eval(expectedForm);
                        string expected;
                        if (Value.IsString(expectedValue))
                        {
                            var s = new string(Value.AsString(expectedValue));
                            expected = s.StartsWith("#<") ? s : Value.PrintRep(expectedValue);
                        }
                        else
                            expected = Value.PrintRep(expectedValue);

                        if (!actual.Equals(expected))
                        {
                            failures++;
                            var loc = assertPos != null ? " at " + assertPos.filename + ":" + assertPos.line : "";
                            failureOutput.AppendLine("  FAIL" + loc);
                            failureOutput.AppendLine("    code:     " + Value.PrintRep(exprForm));
                            failureOutput.AppendLine("    expected: " + expected);
                            failureOutput.AppendLine("    actual:   " + actual);
                        }
                    }
                    catch (Exception e)
                    {
                        failures++;
                        var loc = assertPos != null ? " at " + assertPos.filename + ":" + assertPos.line : "";
                        failureOutput.AppendLine("  FAIL" + loc);
                        failureOutput.AppendLine("    code:      " + Value.PrintRep(exprForm));
                        failureOutput.AppendLine("    exception: " + e.Message);
                    }
                }
                else
                {
                    scheme.Eval(subform);
                }
            }

            scheme.Reset();
            foreach (var pf in preambleForms) scheme.Eval(null, pf);
        }

        return (tests, failures, failureOutput.ToString());
    }

    // ----------------------------------------------------------------
    // Tests runner: evaluate file, it reports on its own
    // ----------------------------------------------------------------

    private static (int tests, int failures) RunTestsTest(string resourceName, string displayName)
    {
        var assembly = typeof(SchemeTests).Assembly;
        var content = new StreamReader(
            assembly.GetManifestResourceStream(resourceName)!
        ).ReadToEnd();

        var total = 0;
        var failed = 0;

        Scheme.StrictImports = true;
        Scheme scheme = Scheme.ForProgram();
        scheme.EvalString(content, resourceName);
        total = (int) Value.AsInteger(scheme.EvalString("(last-run-total-tests)", "scheme-tests"));
        failed = (int) Value.AsInteger(scheme.EvalString("(last-run-failed-tests)", "scheme-tests"));

        return (total, failed);
    }

    // ----------------------------------------------------------------
    // Failure runner: output-comparison tests
    // ----------------------------------------------------------------

    private static (int tests, int failures) RunFailureTests(string platform)
    {
        var assembly = typeof(SchemeTests).Assembly;
        string[] names = assembly.GetManifestResourceNames();
        int tests = 0;
        int failures = 0;

        var testFiles = names
            .Where(n => n.Contains(".failures.") && n.EndsWith(".scm"))
            .OrderBy(n => n)
            .ToArray();

        foreach (var resourceName in testFiles)
        {
            tests++;
            var testFileName = resourceName.Split('.').Reverse().Skip(1).First() + ".scm";
            var baseName = resourceName.Substring(0, resourceName.Length - 4); // strip .scm

            // Find expected output (platform-specific first, then generic)
            string? expectedResource = null;
            var platformSpecific = baseName + ".expected_" + platform;
            var generic = baseName + ".expected";

            if (names.Contains(platformSpecific))
                expectedResource = platformSpecific;
            else if (names.Contains(generic))
                expectedResource = generic;

            if (expectedResource == null)
            {
                Console.WriteLine("  " + testFileName + " SKIP (no .expected file)");
                continue;
            }

            var content = new StreamReader(assembly.GetManifestResourceStream(resourceName)!).ReadToEnd();
            var expectedOutput = new StreamReader(assembly.GetManifestResourceStream(expectedResource)!).ReadToEnd();

            // Capture stdout during test execution
            var originalOut = Console.Out;
            var capturedOutput = new StringWriter();
            Console.SetOut(capturedOutput);

            try
            {
                Scheme.StrictImports = true;
                Scheme scheme = Scheme.ForProgram();
                try
                {
                    scheme.EvalString(content, testFileName);
                }
                catch (SchemeError e)
                {
                    e.PrintStackTrace();
                }
            }
            finally
            {
                Console.SetOut(originalOut);
            }

            var actual = NormalizeOutput(capturedOutput.ToString());
            var expected = NormalizeOutput(expectedOutput);

            if (actual == expected)
            {
                Console.WriteLine("  " + testFileName + " OK");
            }
            else
            {
                failures++;
                Console.WriteLine("  " + testFileName + " FAIL");
                Console.WriteLine("    expected: " + expected.Replace("\n", "\n              "));
                Console.WriteLine("    actual:   " + actual.Replace("\n", "\n              "));
            }
        }

        return (tests, failures);
    }

    private static string NormalizeOutput(string s)
    {
        // Normalize line endings and trim trailing whitespace per line
        return string.Join("\n",
            s.Replace("\r\n", "\n").Replace("\r", "\n")
             .Split('\n')
             .Select(line => line.TrimEnd()))
            .TrimEnd('\n');
    }

    // ----------------------------------------------------------------
    // Main: run categories in order, with command-line filtering
    // ----------------------------------------------------------------

    public static int Main(string[] args)
    {
        var assembly = Assembly.GetExecutingAssembly();
        string[] allResources = assembly.GetManifestResourceNames();
        bool success = true;
        int grandTotalTests = 0;
        int grandTotalFailures = 0;

        // Parse command line: category names, or suite names, or "category:suite"
        var requestedCategories = new HashSet<string>();
        var requestedSuites = new HashSet<string>();
        bool runAll = args.Length == 0;

        foreach (var arg in args)
        {
            if (arg.Contains(':'))
            {
                requestedCategories.Add(arg.Split(':')[0]);
                requestedSuites.Add(arg.Split(':')[1]);
            }
            else if (arg == "core" || arg == "tests" || arg == "failures")
                requestedCategories.Add(arg);
            else
                requestedSuites.Add(arg);
        }

        bool ShouldRunCategory(string cat) =>
            runAll || requestedCategories.Contains(cat) || requestedSuites.Count > 0;

        bool ShouldRunSuite(string suiteName) =>
            runAll || requestedCategories.Count > 0 && requestedSuites.Count == 0 ||
            requestedSuites.Contains(suiteName) ||
            requestedSuites.Contains(Path.GetFileNameWithoutExtension(suiteName));

        // === core ===
        if (ShouldRunCategory("core"))
        {
            Console.WriteLine("=== core ===");
            int catTests = 0, catFailures = 0;

            var coreFiles = allResources
                .Where(n => n.Contains(".core.") && n.EndsWith(".scm"))
                .OrderBy(n => n);

            foreach (var resourceName in coreFiles)
            {
                var displayName = resourceName.Split('.').Reverse().Skip(1).First() + ".scm";
                if (!ShouldRunSuite(displayName)) continue;

                Console.Write("  " + displayName + " ");
                try
                {
                    var (t, f, details) = RunCoreTest(resourceName, displayName);
                    catTests += t;
                    catFailures += f;
                    if (f == 0)
                        Console.WriteLine("OK, " + t + " tests");
                    else
                    {
                        Console.WriteLine("FAIL, " + t + " tests, " + f + " failed");
                        Console.Write(details);
                        success = false;
                    }
                }
                catch (SchemeError e)
                {
                    Console.WriteLine("ERROR");
                    var sw = new StringWriter();
                    var prev = Console.Out;
                    Console.SetOut(sw);
                    e.PrintStackTrace();
                    Console.SetOut(prev);
                    Console.Write(sw.ToString());
                    success = false;
                }
                catch (Exception e)
                {
                    Console.WriteLine("ERROR: " + e.GetType().Name + ": " + e.Message);
                    Console.WriteLine(e.StackTrace);
                    success = false;
                }
            }
            Console.WriteLine("  core: " + catTests + " tests, " + catFailures + " failures");
            Console.WriteLine();
            grandTotalTests += catTests;
            grandTotalFailures += catFailures;
        }

        // === tests ===
        if (ShouldRunCategory("tests"))
        {
            Console.WriteLine("=== tests ===");
            int catTests = 0, catFailures = 0;

            var testFiles = allResources
                .Where(n => n.Contains(".tests.") && n.EndsWith(".scm"))
                .OrderBy(n => n);

            foreach (var resourceName in testFiles)
            {
                var displayName = resourceName.Split('.').Reverse().Skip(1).First() + ".scm";
                if (!ShouldRunSuite(displayName)) continue;

                try
                {
                    var (t, f) = RunTestsTest(resourceName, displayName);

                    catTests += t;
                    catFailures += f;
                    if (f > 0) success = false;
                }
                catch (SchemeError e)
                {
                    Console.WriteLine("ERROR");
                    var sw = new StringWriter();
                    var prev = Console.Out;
                    Console.SetOut(sw);
                    e.PrintStackTrace();
                    Console.SetOut(prev);
                    Console.Write(sw.ToString());
                    success = false;
                }
                catch (Exception e)
                {
                    Console.WriteLine("ERROR: " + e.GetType().Name + ": " + e.Message);
                    Console.WriteLine(e.StackTrace);
                    success = false;
                }
            }
            Console.WriteLine("  tests: " + catTests + " tests, " + catFailures + " failures");
            Console.WriteLine();
            grandTotalTests += catTests;
            grandTotalFailures += catFailures;
        }

        // === failures ===
        if (ShouldRunCategory("failures"))
        {
            Console.WriteLine("=== failures ===");
            try
            {
                var (t, f) = RunFailureTests("csharp");
                grandTotalTests += t;
                grandTotalFailures += f;
                if (f > 0) success = false;
                Console.WriteLine("  failures: " + t + " tests, " + f + " failures");
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("  Failure tests error: " + e.Message);
                success = false;
            }
            Console.WriteLine();
        }

        // === total ===
        Console.WriteLine("=== total ===");
        if (success)
            Console.WriteLine(grandTotalTests + " tests, 0 failures");
        else
            Console.WriteLine(grandTotalTests + " tests, " + grandTotalFailures + " failures");

        return success ? 0 : 1;
    }
}
