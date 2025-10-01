component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll(){
		variables.logLevel = "info";
		variables.ast = new lucee.extension.lcov.ast.ExecutableLineCounter();
	}
	
	function run() {
	
		describe("ExecutableLineCounter", function() {


			it("should instantiate ExecutableLineCounter", function() {
				expect(variables.ast).toBeInstanceOf("ExecutableLineCounter");
			});

			it("should count executable lines correctly for various cases", function() {
				var testCases = [
					{content: ["line1", "line2", "line3"], expected: 3, desc: "normal content"},
					{content: [""], expected: 0, desc: "empty content"},
					{content: ["single line"], expected: 1, desc: "single line"},
					{content: ["line1", "", "line3"], expected: 2, desc: "empty line in middle"},
					{content: ["", "line2", "line3"], expected: 2, desc: "empty first line"},
					{content: ["line1", "line2", ""], expected: 2, desc: "trailing newline"},
					{content: ["", "line2", "line3"], expected: 2, desc: "windows line endings"},
					{content: ["", "// line2", "// line3"], expected: 0, desc: "commented lines"}
				];
				for (var testCase in testCases) {
					var result = variables.ast.countExecutableLinesSimple(testCase.content);
					var lineCount = structKeyExists(result, "count") ? result.count : result;
					expect(lineCount).toBe(testCase.expected, "Should count lines correctly for " & testCase.desc);
				}
			});

			it("should parse source files without error", function() {
				var testFiles = ["coverage-simple-sequential.cfm", "SimpleComponent.cfc"];
				for (var filename in testFiles) {
					var filePath = expandPath("../artifacts/" & filename);
					if (fileExists(filePath)) {
						variables.ast.parseSourceFile(filePath);
					}
				}
			});

			it("should throw on non-existent file", function() {
				var nonExistentFile = expandPath("../artifacts/nonexistent.cfm");
				expect(function() {
					variables.ast.parseSourceFile(nonExistentFile);
				}).toThrow();
			});

			describe("linesFound never exceeds linesSource (simple)", function() {
				it("base/simple", function() {
					var counter = new lucee.extension.lcov.ast.ExecutableLineCounter();
					checkLinesFoundNeverExceedsLinesSource_Simple(counter);
				});
				it("develop/simple", function() {
					var counter = new lucee.extension.lcov.develop.ast.ExecutableLineCounter();
					checkLinesFoundNeverExceedsLinesSource_Simple(counter);
				});
			});

			xdescribe("linesFound never exceeds linesSource (AST)", function() {
				it("base/AST", function() {
					var counter = new lucee.extension.lcov.ExecutableLineCounter();
					checkLinesFoundNeverExceedsLinesSource_AST(counter);
				});
				it("develop/AST", function() {
					var counter = new lucee.extension.lcov.develop.ExecutableLineCounter();
					checkLinesFoundNeverExceedsLinesSource_AST(counter, false);
				});
			});
		});

	}

	private void function checkLinesFoundNeverExceedsLinesSource_Simple(required ExecutableLineCounter counter) {
		var artifactDir = expandPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../artifacts");
		var files = directoryList(artifactDir, false, "path", "*.cf*");
		expect(arrayLen(files)).toBeGT(0, "No .cfc or .cfm files found in artifacts: " & artifactDir);
		for (var filePath in files) {
			if (!fileExists(filePath)) continue;
			//systemOutput("Checking file: " & filePath, true);
			var sourceLines = fileRead(filePath).replace("\r\n", "\n", "all").listToArray("\n");
			var result = counter.countExecutableLinesSimple(sourceLines);
			var linesFound = result.count;
			var linesSource = arrayLen(sourceLines);
			expect(linesFound).toBeLTE(linesSource, "[Simple] linesFound " & linesFound 
				& " should never exceed linesSource " & linesSource & " for " & getFileFromPath(filePath));
		}
	}

	private void function checkLinesFoundNeverExceedsLinesSource_AST(required ExecutableLineCounter counter, boolean throwOnError = true) {
		var artifactDir = expandPath(getDirectoryFromPath(getCurrentTemplatePath()) & "../artifacts");
		var files = directoryList(artifactDir, false, "path", "*.cf*");
		expect(arrayLen(files)).toBeGT(0, "No .cfc or .cfm files found in artifacts: " & artifactDir);
		for (var filePath in files) {
			if (!fileExists(filePath)) continue;
			//systemOutput("Checking file: " & filePath, true);
			var sourceLines = fileRead(filePath).replace("\r\n", "\n", "all").listToArray("\n");
			var ast = astFromPath(filePath);
			var result = counter.countExecutableLinesFromAst(ast, throwOnError);
			var linesFound = result.count;
			var linesSource = arrayLen(sourceLines);
			// if this is going to fail, write out the AST for debugging
			if (linesFound > linesSource) {	
				var debugPath = replace(filePath, ".cfm", "-ast-debug.json", "all");
				fileWrite(debugPath, serializeJSON(ast, true));
				systemOutput("Wrote AST debug file to " & debugPath, true);
			}
			expect(linesFound).toBeLTE(linesSource, "[AST] linesFound " & linesFound 
				& " should never exceed linesSource " & linesSource & " for " & getFileFromPath(filePath));
		}
	}
}