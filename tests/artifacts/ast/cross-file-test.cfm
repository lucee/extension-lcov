<cfscript>
// Cross-file call tree test - demonstrates function calls across multiple components
echo("Starting cross-file call tree test" & chr(10));
echo("" & chr(10));

function orchestrate() {
	var startTime = getTickCount();
	echo("Orchestrator: starting" & chr(10));

	// Create ComponentA and call its methods
	var compA = new ComponentA();

	// Test 1: A calls B which has internal calls
	echo("" & chr(10));
	echo("=== Test 1: A -> B with internal calls ===" & chr(10));
	var result1 = compA.processWithB("test-data-1");
	echo("Result 1: " & result1 & chr(10));

	// Test 2: A calls B which calls C
	echo("" & chr(10));
	echo("=== Test 2: A -> B -> C call chain ===" & chr(10));
	var result2 = compA.analyzeWithB("test-data-2");
	echo("Result 2: " & result2 & chr(10));

	// Test 3: Deeper call chain A -> B -> C with multiple internal calls
	echo("" & chr(10));
	echo("=== Test 3: Deep call chain A -> B -> C ===" & chr(10));
	var result3 = compA.callChain("test-data-3");
	echo("Result 3: " & result3 & chr(10));

	echo("" & chr(10));
	echo("Orchestrator: completed in " & (getTickCount() - startTime) & "ms" & chr(10));
	return {
		result1: result1,
		result2: result2,
		result3: result3
	};
}

// Direct component usage to show another pattern
function directUsage() {
	echo("" & chr(10));
	echo("=== Direct component usage ===" & chr(10));

	var compB = new ComponentB();
	var compC = new ComponentC();

	// Direct B call
	var transformed = compB.transform("direct-data");
	echo("Direct B result: " & transformed & chr(10));

	// Direct C call
	var metrics = compC.calculateMetrics("metric-data");
	echo("Direct C result: " & metrics & chr(10));
}

// Execute the tests
executionStart = getTickCount();
orchestratorResult = orchestrate();
directUsage();
totalTime = getTickCount() - executionStart;

echo("" & chr(10));
echo("=====================================" & chr(10));
echo("Total execution time: " & totalTime & "ms" & chr(10));
echo("" & chr(10));
echo("Expected call tree structure:" & chr(10));
echo("orchestrate() [cross-file-test.cfm]" & chr(10));
echo("  ├── ComponentA.processWithB()" & chr(10));
echo("  │   ├── ComponentB.init()" & chr(10));
echo("  │   ├── ComponentB.transform()" & chr(10));
echo("  │   │   └── ComponentB.cleanData()" & chr(10));
echo("  │   └── ComponentB.validate()" & chr(10));
echo("  │       └── ComponentB.checkRules()" & chr(10));
echo("  ├── ComponentA.analyzeWithB()" & chr(10));
echo("  │   ├── ComponentB.init()" & chr(10));
echo("  │   ├── ComponentB.analyze()" & chr(10));
echo("  │   │   ├── ComponentC.init()" & chr(10));
echo("  │   │   └── ComponentC.calculateMetrics()" & chr(10));
echo("  │   │       ├── ComponentC.computeStatistics()" & chr(10));
echo("  │   │       └── ComponentC.computeScore()" & chr(10));
echo("  │   └── ComponentA.enhanceResult()" & chr(10));
echo("  └── ComponentA.callChain()" & chr(10));
echo("      ├── ComponentB.init()" & chr(10));
echo("      └── ComponentB.callC()" & chr(10));
echo("          ├── ComponentC.init()" & chr(10));
echo("          └── ComponentC.processDeep()" & chr(10));
echo("              ├── ComponentC.firstPass()" & chr(10));
echo("              ├── ComponentC.secondPass()" & chr(10));
echo("              └── ComponentC.finalPass()" & chr(10));
echo("" & chr(10));
echo("directUsage() [cross-file-test.cfm]" & chr(10));
echo("  ├── ComponentB.init()" & chr(10));
echo("  ├── ComponentB.transform()" & chr(10));
echo("  │   └── ComponentB.cleanData()" & chr(10));
echo("  ├── ComponentC.init()" & chr(10));
echo("  └── ComponentC.calculateMetrics()" & chr(10));
echo("      ├── ComponentC.computeStatistics()" & chr(10));
echo("      └── ComponentC.computeScore()" & chr(10));
echo("" & chr(10));
echo("This demonstrates:" & chr(10));
echo("- Cross-file function calls" & chr(10));
echo("- Multiple component instances" & chr(10));
echo("- Call chains across 3+ files" & chr(10));
echo("- Own time vs total time across files" & chr(10));
</cfscript>