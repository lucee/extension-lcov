
component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function beforeAll() {
		variables.testDataHelper = new "../GenerateTestData"("synthetic-html");
	}

	/**
	 * Test the HTML reporter with synthetic coverage data (no file I/O)
	 */
	function testHtmlReporterWithSyntheticData() {
		var HtmlReporter = new lucee.extension.lcov.reporter.HtmlReporter();
		var outDir = variables.testDataHelper.getGeneratedArtifactsDir();
		HtmlReporter.setOutputDir(outDir);
		// Synthetic result object: 2 files, one fully covered, one partially covered
		// Use a CFC instance to match the model API and allow member access
		var syntheticResult = new lucee.extension.lcov.model.result();
		
		syntheticResult.setExeLog(outDir & "/synthetic.exl");
		syntheticResult.setStats({
			totalLinesFound: 10,
			totalLinesHit: 7,
			totalLinesSource: 10,
			coveragePercentage: 70,
			totalFiles: 2,
			linesFound: 10,
			linesHit: 7,
			totalExecutions: 17,
			totalExecutionTime: 123
		});
		// Add per-file stats to match model expectations
		// Use numeric file indices for all per-file data
		var filePaths = [outDir & "/FullyCovered.cfm", outDir & "/PartiallyCovered.cfm"];
		// fileIndex 0 = FullyCovered.cfm, fileIndex 1 = PartiallyCovered.cfm
		syntheticResult.setStatsProperty("files", {
			0: { linesFound: 5, linesHit: 5, totalExecutions: 10, totalExecutionTime: 60 },
			1: { linesFound: 5, linesHit: 2, totalExecutions: 7, totalExecutionTime: 63 }
		});
		syntheticResult.setFiles({
			0: {
				path: filePaths[1], // 0-based: filePaths[1] is FullyCovered.cfm
				linesFound: 5,
				linesHit: 5,
				linesSource: 5,
				coveragePercentage: 100,
				totalExecutions: 10,
				totalExecutionTime: 60,
				lines: ["line1", "line2", "line3", "line4", "line5"],
				executableLines: {}
			},
			1: {
				path: filePaths[2], // 0-based: filePaths[2] is PartiallyCovered.cfm
				linesFound: 5,
				linesHit: 2,
				linesSource: 5,
				coveragePercentage: 40,
				totalExecutions: 7,
				totalExecutionTime: 63,
				lines: ["line1", "line2", "line3", "line4", "line5"],
				executableLines: {}
			}
		});
		
		syntheticResult.setCoverage({
			total: 70,
			0: { linesFound: 5, linesHit: 5, coveragePercentage: 100 },
			1: { linesFound: 5, linesHit: 2, coveragePercentage: 40 }
		});
		syntheticResult.setMetadata({ "script-name": "synthetic.cfm", "execution-time": 123, "unit": "ms" });

		// Set outputFilename for the synthetic result (required by HtmlReporter)
		syntheticResult.setOutputFilename("synthetic-html-test");
		// Generate HTML report and get the file path
		// Provide a displayUnit struct with a symbol property as expected by the reporter
		var displayUnit = { symbol: "μs", name: "micro", factor: 1 };
		var htmlPath = HtmlReporter.generateHtmlReport(syntheticResult, displayUnit);
		systemOutput("Generated HTML path: " & htmlPath, true);

		// Read the generated HTML file
		var html = fileRead(htmlPath);
		var doc = htmlParse(html);
		// Write the parsed XML doc to a file for inspection
		var xmlOutPath = outDir & "/synthetic-html-parsed.xml";
		fileWrite(xmlOutPath, toString(doc));
		systemOutput("Wrote parsed XML to: " & xmlOutPath, true);

		// Assert: file sections exist for all files using xmlSearch (namespace-agnostic)
		var files = syntheticResult.getFiles();
		var fileSections = xmlSearch(doc, "//*[local-name()='div' and @data-file-section]");
		expect(arrayLen(fileSections)).toBe(structCount(files));
		// Assert the data-file-section attribute value is 'data-file-section'
		fileSections.each(function(n){ expect(n.xmlAttributes["data-file-section"]).toBe("data-file-section"); });
		var filenames = fileSections.map(function(n){ return n.xmlAttributes["data-filename"]; });
		for (var idx in files) {
			expect(filenames).toInclude(files[idx].path);
		}

			// Assert: line rows exist and have correct attributes (namespace-agnostic)
		var lineRows = xmlSearch(doc, "//*[local-name()='tr' and @data-line-row]");
		var totalLines = 0;
		for (var idx in files) {
			totalLines += files[idx].linesSource;
		}
		expect(arrayLen(lineRows)).toBe(totalLines);
		// Check exact number of line rows for each file using syntheticResult
		for (var idx in files) {
			var filePath = files[idx].path;
			var fileRows = xmlSearch(doc, "//*[local-name()='div' and @data-file-section and @data-filename='" & filePath & "']//*[local-name()='tr' and @data-line-row]");
			expect(arrayLen(fileRows)).toBe(files[idx].linesSource);
		}

		// Assert: summary section exists and contains correct percentage (namespace-agnostic)
		var summary = xmlSearch(doc, "//*[@data-coverage-summary]");
		expect(arrayLen(summary)).toBe(1);
		var expectedPct = syntheticResult.getStats().coveragePercentage & ".0%";
		expect(summary[1].xmlText).toInclude(expectedPct);
	}

}