package;

/**
 * Test runner: runs the hand written tests and the XML fixtures.
 *
 * Usage: `node bin/test.js [fixturesDir] [--category <name>] [--filter <substring>] [--verbose] [--failures <file>] [--no-unit] [--dump <file>] [--relayout-check]`
 *
 * The fixtures directory defaults to the `TAFFY_FIXTURES` environment variable, then to `fixtures`
 * (the small subset copied in this repository). It must contain one folder per category
 * (`block`, `flex`, `grid`...), like `tests/xml` in the taffy repository.
 */
class Main {

    static function main() {
        final args = FileIO.args();
        var fixturesDir:Null<String> = null;
        var category:Null<String> = null;
        var filter:Null<String> = null;
        var verbose = false;
        var failuresFile:Null<String> = null;
        var runUnit = true;
        var dumpFile:Null<String> = null;
        var i = 0;
        while (i < args.length) {
            final arg = args[i];
            switch arg {
                case "--category":
                    category = args[++i];
                case "--filter":
                    filter = args[++i];
                case "--verbose":
                    verbose = true;
                case "--failures":
                    failuresFile = args[++i];
                case "--no-unit":
                    runUnit = false;
                case "--dump":
                    dumpFile = args[++i];
                    XmlTests.dump = new StringBuf();
                case "--relayout-check":
                    XmlTests.relayoutCheck = true;
                case "--cutoff-check":
                    XmlTests.cutoffCheck = true;
                case _:
                    fixturesDir = arg;
            }
            i++;
        }
        if (fixturesDir == null)
            fixturesDir = FileIO.env("TAFFY_FIXTURES");
        if (fixturesDir == null)
            fixturesDir = "fixtures";

        var allOk = true;

        if (runUnit && filter == null && category == null) {
            final suites = [
                {name: "hand written tests", run: HandWrittenTests.run},
                {name: "flexbox unit tests", run: FlexboxUnitTests.run},
                {name: "grid unit tests", run: GridUnitTests.run},
                {name: "optional float tests", run: OptionalFloatTests.run},
                {name: "f32 literal tests", run: F32LiteralTests.run}
            ];
            for (suite in suites) {
                final unit = suite.run();
                FileIO.println('${suite.name}: ${unit.passed} / ${unit.total} passed');
                for (f in unit.failures)
                    FileIO.println('  FAIL ' + f);
                if (unit.passed != unit.total)
                    allOk = false;
            }
        }

        final failures:Array<String> = [];
        var totalPassed = 0;
        var totalCount = 0;
        for (cat in XmlTests.CATEGORIES) {
            if (category != null && category != cat)
                continue;
            final dir = fixturesDir + "/" + cat;
            if (!FileIO.exists(dir))
                continue;
            var passed = 0;
            var count = 0;
            for (file in FileIO.readDirectory(dir)) {
                if (!StringTools.endsWith(file, ".xml"))
                    continue;
                final name = file.substr(0, file.length - 4);
                if (filter != null && name.indexOf(filter) == -1)
                    continue;
                count++;
                var ok = false;
                var details = "";
                if (XmlTests.dump != null)
                    XmlTests.dump.add(cat + "/" + name + "\n");
                try {
                    final result = XmlTests.runXmlTest(FileIO.readFile(dir + "/" + file));
                    ok = result.passed;
                    details = result.details;
                }
                catch (e:haxe.Exception) {
                    details = "EXCEPTION: " + e.message + "\n" + e.stack.toString();
                }
                catch (e:Dynamic) {
                    details = "EXCEPTION: " + Std.string(e);
                }
                if (ok) {
                    passed++;
                }
                else {
                    failures.push(cat + "/" + name);
                    if (verbose) {
                        FileIO.println('FAIL $cat/$name');
                        FileIO.println(details);
                    }
                }
            }
            totalPassed += passed;
            totalCount += count;
            if (count > 0)
                FileIO.println('$cat: $passed / $count passed');
        }
        FileIO.println('total: $totalPassed / $totalCount passed');
        if (XmlTests.cutoffCheck)
            FileIO.println('cutoff check: ${XmlTests.cutoffChecked} nodes replaced and checked (${XmlTests.cutoffNotMatched} not matched, laid out again), ${XmlTests.cutoffSkipped} skipped (lossy cache or out of flow)');
        if (dumpFile != null)
            FileIO.writeFile(dumpFile, XmlTests.dump.toString());
        if (failuresFile != null)
            FileIO.writeFile(failuresFile, failures.join("\n") + "\n");
        if (totalPassed != totalCount)
            allOk = false;
        #if (taffy_census && !js)
        FileIO.println(taffy.util.Census.report());
        #end
        FileIO.exit(allOk ? 0 : 1);
    }

}
