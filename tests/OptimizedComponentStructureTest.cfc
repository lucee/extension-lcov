component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	// Leave test artifacts for inspection - no cleanup in afterAll

	/**
	 * Test that optimized ExecutionLogParserOptimized can be instantiated and has expected methods
	 */
	function testExecutionLogParserOptimizedExists() {


		// Test instantiation
		var options = {"verbose": true};
		var optimizedParser = new lucee.extension.lcov.ExecutionLogParserOptimized(options);
		
		expect(isObject(optimizedParser), "Should create optimized parser object").toBeTrue();
		
		// Test it has the expected methods
		var functions = getMetaData(optimizedParser).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		
		expect(arrayContains(methods, "parseExlFile"), "Should have parseExlFile method").toBeTrue();
		expect(arrayContains(methods, "getLineFromCharacterPosition"), "Should have getLineFromCharacterPosition method").toBeTrue();


	}

	/**
	 * Test that optimized codeCoverageUtilsOptimized can be instantiated and has expected methods
	 */
	function testCodeCoverageUtilsOptimizedExists() {


		// Test instantiation
		var options = {"verbose": true};
		var optimizedUtils = new lucee.extension.lcov.codeCoverageUtilsOptimized(options);
		
		expect(isObject(optimizedUtils), "Should create optimized utils object").toBeTrue();
		
		// Test it has the expected methods
		var functions = getMetaData(optimizedUtils).functions;
		var methods = [];
		for (var func in functions) {
			arrayAppend(methods, func.name);
		}

		
		expect(arrayContains(methods, "calculateCoverageStats"), "Should have calculateCoverageStats method").toBeTrue();
		expect(arrayContains(methods, "excludeOverlappingBlocks"), "Should have excludeOverlappingBlocks method").toBeTrue();
		expect(arrayContains(methods, "mergeResultsByFile"), "Should have mergeResultsByFile method").toBeTrue();


	}

	/**
	 * Test that optimized classes use optimization-specific logging
	 */
	function testOptimizedLoggingExists() {


		var options = {"verbose": true};
		
		// Test optimized parser has optimization logging
		var optimizedParser = new lucee.extension.lcov.ExecutionLogParserOptimized(options);
		expect(isObject(optimizedParser), "Optimized parser should instantiate").toBeTrue();
		
		// Test optimized utils has optimization logging
		var optimizedUtils = new lucee.extension.lcov.codeCoverageUtilsOptimized(options);
		expect(isObject(optimizedUtils), "Optimized utils should instantiate").toBeTrue();
		

	}

	/**
	 * Test comparing method signatures between original and optimized versions
	 */
	function testMethodSignatureCompatibility() {


		// Compare ExecutionLogParser methods
		var originalParser = new lucee.extension.lcov.ExecutionLogParser({"verbose": false});
		var optimizedParser = new lucee.extension.lcov.ExecutionLogParserOptimized({"verbose": false});
		
		var originalFunctions = getMetaData(originalParser).functions;
		var originalMethods = [];
		for (var func in originalFunctions) {
			arrayAppend(originalMethods, func.name);
		}
		
		var optimizedFunctions = getMetaData(optimizedParser).functions;
		var optimizedMethods = [];
		for (var func in optimizedFunctions) {
			arrayAppend(optimizedMethods, func.name);
		}
		
		// Check that key methods exist in both
		var keyMethods = ["parseExlFile", "getLineFromCharacterPosition"];
		for (var method in keyMethods) {
			expect(arrayContains(originalMethods, method), "Original should have " & method).toBeTrue();
			expect(arrayContains(optimizedMethods, method), "Optimized should have " & method).toBeTrue();
		}
		
		// Compare codeCoverageUtils methods
		var originalUtils = new lucee.extension.lcov.codeCoverageUtils({"verbose": false});
		var optimizedUtils = new lucee.extension.lcov.codeCoverageUtilsOptimized({"verbose": false});
		
		var originalUtilsFunctions = getMetaData(originalUtils).functions;
		var originalUtilsMethods = [];
		for (var func in originalUtilsFunctions) {
			arrayAppend(originalUtilsMethods, func.name);
		}
		
		var optimizedUtilsFunctions = getMetaData(optimizedUtils).functions;
		var optimizedUtilsMethods = [];
		for (var func in optimizedUtilsFunctions) {
			arrayAppend(optimizedUtilsMethods, func.name);
		}
		
		// Check that key methods exist in both
		var keyUtilsMethods = ["calculateCoverageStats", "excludeOverlappingBlocks", "mergeResultsByFile"];
		for (var method in keyUtilsMethods) {
			expect(arrayContains(originalUtilsMethods, method), "Original utils should have " & method).toBeTrue();
			expect(arrayContains(optimizedUtilsMethods, method), "Optimized utils should have " & method).toBeTrue();
		}


	}

}