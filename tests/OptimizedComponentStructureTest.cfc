component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	// Leave test artifacts for inspection - no cleanup in afterAll

	/**
	 * Test that develop ExecutionLogParser can be instantiated and has expected methods
	 */
	function testExecutionLogParserExists() {


		// Test instantiation
		var options = {"verbose": true};
		var developParser = new lucee.extension.lcov.develop.ExecutionLogParser(options);

		expect(isObject(developParser), "Should create develop parser object").toBeTrue();

		// Test it has the expected methods
		var functions = getMetaData(developParser).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		expect(arrayContains(methods, "parseExlFile"), "Should have parseExlFile method").toBeTrue();
		expect(arrayContains(methods, "getLineFromCharacterPosition"), "Should have getLineFromCharacterPosition method").toBeTrue();

	}

	/**
	 * Test that develop CoverageBlockProcessor can be instantiated and has expected methods
	 */
	function testCoverageBlockProcessorDevelopExists() {

		// Test instantiation
		var options = {"verbose": true};
		var developUtils = new lucee.extension.lcov.develop.CoverageBlockProcessor(options);

		expect(isObject(developUtils), "Should create develop utils object").toBeTrue();

		// Test it has the expected methods
		var functions = getMetaData(developUtils).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		expect(arrayContains(methods, "calculateCoverageStats"), "Should have calculateCoverageStats method").toBeTrue();
		expect(arrayContains(methods, "excludeOverlappingBlocks"), "Should have excludeOverlappingBlocks method").toBeTrue();
		// Removed: mergeResultsByFile is no longer a method of CoverageBlockProcessor

	}

	/**
	 * Test that develop classes use optimization-specific logging
	 */
	function testdevelopLoggingExists() {

		var options = {"verbose": true};

		// Test develop parser has optimization logging
		var developParser = new lucee.extension.lcov.develop.ExecutionLogParser(options);
		expect(isObject(developParser), "develop parser should instantiate").toBeTrue();

		// Test develop utils has optimization logging
		var developUtils = new lucee.extension.lcov.develop.CoverageBlockProcessor(options);
		expect(isObject(developUtils), "develop utils should instantiate").toBeTrue();

	}

	/**
	 * Test comparing method signatures between stable and develop versions
	 */
	function testMethodSignatureCompatibility() {

		// Compare ExecutionLogParser methods
		var stablelParser = new lucee.extension.lcov.ExecutionLogParser({"verbose": false});
		var developParser = new lucee.extension.lcov.develop.ExecutionLogParser({"verbose": false});

		var stableFunctions = getMetaData(stablelParser).functions;
		var stableMethods = [];
		for (var func in stableFunctions) {
			arrayAppend(stableMethods, func.name);
		}

		var developFunctions = getMetaData(developParser).functions;
		var developMethods = [];
		for (var func in developFunctions) {
			arrayAppend(developMethods, func.name);
		}

		// Check that key methods exist in both
		var keyMethods = ["parseExlFile", "getLineFromCharacterPosition"];
		for (var method in keyMethods) {
			expect(stableMethods).toInclude(method, "stable should have " & method);
			expect(developMethods).toInclude(method, "develop should have " & method);
		}

		// Compare CoverageBlockProcessor methods
		var stableUtils = new lucee.extension.lcov.CoverageBlockProcessor({"verbose": false});
		var developUtils = new lucee.extension.lcov.develop.CoverageBlockProcessor({"verbose": false});

		var stableUtilsFunctions = getMetaData(stableUtils).functions;
		var stableUtilsMethods = [];
		for (var func in stableUtilsFunctions) {
			arrayAppend(stableUtilsMethods, func.name);
		}

		var developUtilsFunctions = getMetaData(developUtils).functions;
		var developUtilsMethods = [];
		for (var func in developUtilsFunctions) {
			arrayAppend(developUtilsMethods, func.name);
		}

		// Check that key methods exist in both
		// Stable utils: only require calculateLcovStats and excludeOverlappingBlocks
		expect(stableUtilsMethods).toInclude("calculateLcovStats", "stable utils should have calculateLcovStats");
		expect(stableUtilsMethods).toInclude("excludeOverlappingBlocks", "stable utils should have excludeOverlappingBlocks");

		// Develop utils: require calculateCoverageStats and excludeOverlappingBlocks
		expect(developUtilsMethods).toInclude("calculateCoverageStats", "develop utils should have calculateCoverageStats");
		expect(developUtilsMethods).toInclude("excludeOverlappingBlocks", "develop utils should have excludeOverlappingBlocks");

	}

}