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
	 * Test that develop codeCoverageUtils can be instantiated and has expected methods
	 */
	function testCodeCoverageUtilsDevelopExists() {

		// Test instantiation
		var options = {"verbose": true};
		var developUtils = new lucee.extension.lcov.develop.codeCoverageUtils(options);

		expect(isObject(developUtils), "Should create develop utils object").toBeTrue();

		// Test it has the expected methods
		var functions = getMetaData(developUtils).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		expect(arrayContains(methods, "calculateCoverageStats"), "Should have calculateCoverageStats method").toBeTrue();
		expect(arrayContains(methods, "excludeOverlappingBlocks"), "Should have excludeOverlappingBlocks method").toBeTrue();
		expect(arrayContains(methods, "mergeResultsByFile"), "Should have mergeResultsByFile method").toBeTrue();

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
		var developUtils = new lucee.extension.lcov.develop.codeCoverageUtils(options);
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
			expect(arrayContains(stableMethods, method), "stable should have " & method).toBeTrue();
			expect(arrayContains(developMethods, method), "develop should have " & method).toBeTrue();
		}

		// Compare codeCoverageUtils methods
		var stableUtils = new lucee.extension.lcov.codeCoverageUtils({"verbose": false});
				var developUtils = new lucee.extension.lcov.develop.codeCoverageUtils({"verbose": false});

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
		var keyUtilsMethods = ["calculateCoverageStats", "excludeOverlappingBlocks", "mergeResultsByFile"];
		for (var method in keyUtilsMethods) {
			expect(arrayContains(stableUtilsMethods, method), "stable utils should have " & method).toBeTrue();
			expect(arrayContains(developUtilsMethods, method), "develop utils should have " & method).toBeTrue();
		}

	}

}