component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	

	/**
	 * Test that develop ExecutionLogParser can be instantiated and has expected methods
	 */
	function testExecutionLogParserExists() {


		// Test instantiation
		var options = {"verbose": true};
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var developParser = factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=true, initArgs=options);

		expect(developParser, "Should create develop parser object").toBeTypeOf("object");

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
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var developUtils = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=true, initArgs=options);

		expect(developUtils, "Should create develop utils object").toBeTypeOf("object");

		// Test it has the expected methods
		var functions = getMetaData(developUtils).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		expect(methods).toInclude("filterOverlappingBlocksLineBased");
		expect(methods).toInclude("filterOverlappingBlocksPositionBased");
	}

	/**
	 * Test that develop classes use optimization-specific logging
	 */
	function testdevelopLoggingExists() {

		var options = {"verbose": true};

		// Test develop parser has optimization logging
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var developParser = factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=true, initArgs=options);
		expect(developParser).toBeTypeOf("object");

		// Test develop utils has optimization logging
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var developUtils = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=true, initArgs=options);
		expect(developUtils).toBeTypeOf("object");

	}

	/**
	 * Test comparing method signatures between stable and develop versions
	 */
	function testMethodSignatureCompatibility() {

		// Compare ExecutionLogParser methods
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var stablelParser = factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false, initArgs={"verbose": false});
		var developParser = factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=true, initArgs={"verbose": false});

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
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var stableBlock = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=false);
		var developBlock = factory.getComponent(name="CoverageBlockProcessor", overrideUseDevelop=true);

		var stableBlockFunctions = getMetaData(stableBlock).functions;
		var stableBlockMethods = [];
		for (var func in stableBlockFunctions) {
			arrayAppend(stableBlockMethods, func.name);
		}

		var developBlockFunctions = getMetaData(developBlock).functions;
		var developBlockMethods = [];
		for (var func in developBlockFunctions) {
			arrayAppend(developBlockMethods, func.name);
		}

		expect(stableBlockMethods).toInclude("filterOverlappingBlocksLineBased");
		expect(stableBlockMethods).toInclude("filterOverlappingBlocksPositionBased");
		expect(developBlockMethods).toInclude("filterOverlappingBlocksLineBased");
		expect(developBlockMethods).toInclude("filterOverlappingBlocksPositionBased");

		// Compare CoverageStats methods
		var factory = new lucee.extension.lcov.CoverageComponentFactory();
		var stableStats = factory.getComponent(name="CoverageStats", overrideUseDevelop=false);
		var developStats = factory.getComponent(name="CoverageStats", overrideUseDevelop=true);

		var stableStatsFunctions = getMetaData(stableStats).functions;
		var stableStatsMethods = [];
		for (var func in stableStatsFunctions) {
			arrayAppend(stableStatsMethods, func.name);
		}

		var developStatsFunctions = getMetaData(developStats).functions;
		var developStatsMethods = [];
		for (var func in developStatsFunctions) {
			arrayAppend(developStatsMethods, func.name);
		}

		expect(stableStatsMethods).toInclude("calculateLcovStats");
		expect(developStatsMethods).toInclude("calculateCoverageStats");

	}

}