component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll(){
		variables.logLevel = "info";
		variables.logger = new lucee.extension.lcov.Logger( level=variables.logLevel );
		variables.ast = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );
	}
	
	function run() {
	
		describe("ExecutableLineCounter", function() {


			it("should instantiate ExecutableLineCounter", function() {
				expect(variables.ast).toBeInstanceOf("ExecutableLineCounter");
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

			xit("linesFound never exceeds linesSource (AST)", function() {
				var counter = new lucee.extension.lcov.ast.ExecutableLineCounter( logger=variables.logger );
				checkLinesFoundNeverExceedsLinesSource_AST( counter );
			});
		});

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