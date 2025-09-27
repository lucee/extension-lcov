component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.factory = new lucee.extension.lcov.CoverageComponentFactory();
		variables.adminPassword = request.SERVERADMINPASSWORD;

		// Create test directory
		variables.tempDir = expandPath("/testdata/ExecutionLogParserExceptionTest");
		if (!directoryExists(variables.tempDir)) {
			directoryCreate(variables.tempDir);
		}

		// Leave test artifacts for inspection - no cleanup in afterAll
	}

	function run() {
		describe("ExecutionLogParser - Exception Handling", function() {
			it("should handle execution logs with empty coverage section", function() {
				// Create a minimal .exl file with empty coverage section
				// This simulates what happens when a request fails or throws an error
				var testExlPath = variables.tempDir & "/minimal.exl";

				// Create a test file so it exists
				var testFilePath = variables.tempDir & "/test-file.cfm";
				// avoid CFML parsing issues by breaking up the cfscript tag
				fileWrite(testFilePath, "<"& "cf" & "script>" & chr(10) &
					"// test file" & chr(10) &
					"</" & "cf" & "script>");

				var content = [
					"unit=MICROSECONDS",
					"min-time=0",
					"",  // First empty line (end of metadata)
					"0" & chr(9) & testFilePath,
					"",  // Second empty line (end of files, start of coverage - but no coverage data)
					""   // File might end here
				];

				fileWrite(testExlPath, arrayToList(content, chr(10)));

				// This should NOT throw an error about arraySlice
				var parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);

				// This should NOT throw an error about arraySlice after fix
				var result = {};
				var errorThrown = false;
				try {
					result = parser.parseExlFile(testExlPath);
				} catch (any e) {
					errorThrown = true;
					// If error occurs, it shouldn't be arraySlice related
					expect(e.message).notToInclude("Offset cannot be greater than size of the array",
						"Should not have arraySlice error after fix. Got: #e.message#");
				}

				// After fix, it should parse successfully
				expect(errorThrown).toBeFalse("Parser should not throw error after fix");
				expect(isObject(result)).toBeTrue("Should return a result object");
				expect(isInstanceOf(result, "lucee.extension.lcov.model.result")).toBeTrue("Should be a result component");
				// Use the getter method instead of direct access
				expect( structCount(result.getFiles()) ).toBeGTE(0, 
					"Should have files property (may be empty)");
			});

			it("should handle execution logs that end immediately after files section", function() {
				// Another edge case - file ends right after files section
				var testExlPath = variables.tempDir & "/no-coverage.exl";

				// Create a test file so it exists
				var testFilePath = variables.tempDir & "/test-file2.cfm";
				// avoid CFML parsing issues by breaking up the cfscript tag
				fileWrite(testFilePath, "<" & "cf" & "script>" & chr(10) &
					"// test file 2" & chr(10) &
					"</" & "cf" & "script>");

				var content = [
					"unit=MICROSECONDS",
					"min-time=0",
					"",
					"0" & chr(9) & testFilePath,
					""  // Second empty line then EOF
				];

				fileWrite(testExlPath, arrayToList(content, chr(10)));

				var parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);

				// After fix, this should parse successfully
				var errorThrown = false;
				var result = {};
				try {
					result = parser.parseExlFile(testExlPath);
				} catch (any e) {
					errorThrown = true;
				}

				expect(errorThrown).toBeFalse("Parser should not throw error after fix");
				expect(isObject(result)).toBeTrue("Should return a result object");
				expect(isInstanceOf(result, "lucee.extension.lcov.model.result")).toBeTrue("Should be a result component");
			});

			it("should handle execution logs with file that doesn't exist", function() {
				// Create a .exl file that references a non-existent file
				var testExlPath = variables.tempDir & "/nonexistent.exl";

				var content = [
					"unit=MICROSECONDS",
					"min-time=0",
					"",  // First empty line (end of metadata)
					"0" & chr(9) & "D:\nonexistent\file.cfm",  // This file doesn't exist
					"",  // Second empty line
					""
				];

				fileWrite(testExlPath, arrayToList(content, chr(10)));

				var parser = variables.factory.getComponent(name="ExecutionLogParser", overrideUseDevelop=false);

				// This should throw an ExecutionLogParser.SourceFileNotFound error
				var errorThrown = false;
				var errorType = "";
				try {
					var result = parser.parseExlFile(testExlPath);
				} catch (any e) {
					errorThrown = true;
					errorType = e.type;
				}

				expect(errorThrown).toBeTrue("Should throw error for non-existent source file");
				expect(errorType).toBe("ExecutionLogParser.SourceFileNotFound", "Should throw specific error type");
			});
		});
	}
}