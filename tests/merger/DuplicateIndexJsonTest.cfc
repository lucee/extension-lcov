component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	public void function beforeAll(){
		// Use GenerateTestData with test name - handles directory creation and cleanup
		variables.testDataGenerator = new "../GenerateTestData"(testName="DuplicateIndexJsonTest");

		// Generate test data
		variables.testData = variables.testDataGenerator.generateExlFilesForArtifacts(request.SERVERADMINPASSWORD);
		variables.testExlDir = variables.testData.coverageDir;

		variables.htmlOutputDir = "#variables.testData.coverageDir#\html-output";
		variables.jsonOutputDir = "#variables.testData.coverageDir#\json-output";
		variables.jsonOnlyOutputDir = "#variables.testData.coverageDir#\json-only-output";

	}

	public void function testHtmlGenerationWithRealExlFilesDoesNotProduceDuplicateIndexEntries() {
		
		// Clean and create output directories
		if (directoryExists(variables.htmlOutputDir)) {
			directoryDelete(variables.htmlOutputDir, true);
		}
		if (directoryExists(variables.jsonOutputDir)) {
			directoryDelete(variables.jsonOutputDir, true);
		}
		directoryCreate(variables.htmlOutputDir, true);
		directoryCreate(variables.jsonOutputDir, true);

		// Use the test execution logs directory
		var results = lcovGenerateHtml(
			executionLogDir = variables.testExlDir,
			outputDir = variables.htmlOutputDir,
			generateJson = true,
			jsonOutputDir = variables.jsonOutputDir
		);

		// If no exception was thrown, generation succeeded

		// Check that index.json was generated in HTML output directory
		var indexJsonPath = "#variables.htmlOutputDir#\index.json";
		expect(fileExists(indexJsonPath)).toBeTrue("index.json should be generated in HTML output directory");

		// Read and parse the index.json
		var indexContent = fileRead(indexJsonPath);
		var indexData = deserializeJSON(indexContent);

		expect(isArray(indexData)).toBeTrue("Index should be array");

		// Create a struct to track unique entries by key properties
		var uniqueEntries = {};
		var duplicateCount = 0;

		for (var i = 1; i <= arrayLen(indexData); i++) {
			var entry = indexData[i];

			// Create a unique key from critical properties
			var entryKey = "#entry.scriptName#|#entry.totalExecutions#|#entry.totalLinesFound#|#entry.totalLinesHit#";

			if (structKeyExists(uniqueEntries, entryKey)) {
				duplicateCount++;
				systemOutput("DUPLICATE FOUND: Entry #i# matches entry #uniqueEntries[entryKey]#", true);
				systemOutput("  Script: #entry.scriptName#", true);
				systemOutput("  Total Executions: #entry.totalExecutions#", true);
				systemOutput("  Lines Found: #entry.totalLinesFound#", true);
				systemOutput("  Lines Hit: #entry.totalLinesHit#", true);
			} else {
				uniqueEntries[entryKey] = i;
				//systemOutput("UNIQUE: Entry #i# - #entry.scriptName# (#entry.totalExecutions# exec, #entry.totalLinesHit#/#entry.totalLinesFound# lines)");
			}
		}

		//systemOutput("Total entries: #arrayLen(indexData)#, Unique: #structCount(uniqueEntries)#, Duplicates: #duplicateCount#");

		// The test should fail if duplicates are found
		expect(duplicateCount).toBe(0, "Found #duplicateCount# duplicate entries in index.json - all entries should be unique");
		expect(structCount(uniqueEntries)).toBe(arrayLen(indexData), "Number of unique entries should equal total entries");

		// Create a struct to track unique entries
		var uniqueEntries = {};
		var duplicateCount = 0;

		for (var i = 1; i <= arrayLen(indexData); i++) {
			var entry = indexData[i];
			var entryKey = "#entry.scriptName#|#entry.totalExecutions#|#entry.totalLinesFound#|#entry.totalLinesHit#";

			if (structKeyExists(uniqueEntries, entryKey)) {
				duplicateCount++;
			} else {
				uniqueEntries[entryKey] = i;
			}
		}

		expect(duplicateCount).toBe(0, "Found #duplicateCount# duplicate entries in JSON-only index.json");
	}

	public void function testJsonGenerationWithRealExlFilesDoesNotProduceDuplicateIndexEntries() {
		// Clean and create output directory
		if (directoryExists(variables.jsonOnlyOutputDir)) {
			directoryDelete(variables.jsonOnlyOutputDir, true);
		}
		directoryCreate(variables.jsonOnlyOutputDir, true);

		// Use JSON-only generation
		var results = lcovGenerateJson(
			executionLogDir = variables.testExlDir,
			outputDir = variables.jsonOnlyOutputDir
		);

		// systemOutput("JSON Generation Results: #serializeJSON(var=results,compact=false)#", true);

		// If no exception was thrown, generation succeeded

		// Check that index.json was generated in JSON output directory
		arrayEach(["merged.json", "summary-stats.json", "results.json"], function(fileName) {
			var filePath = "#variables.jsonOnlyOutputDir#\#fileName#";
			expect(fileExists(filePath)).toBeTrue("#fileName# should be generated in JSON output directory [" & variables.jsonOnlyOutputDir & "]");
		});
		
		
	}
}