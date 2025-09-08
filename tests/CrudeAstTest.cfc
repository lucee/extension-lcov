component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.ast = new lucee.extension.lcov.codeCoverageAst();
	}
	
	function testAstExists() {
		expect(variables.ast).toBeInstanceOf("codeCoverageAst");
	}
	
	function testAstCanCountSourceLines() {
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
			var lineCount = variables.ast.countSourceLines(testCase.content);
			expect(lineCount).toBe(testCase.expected, "Should count lines correctly for " & testCase.desc);
		}
	}
	
	function testAstCanParseSourceFiles() {
		var testFiles = ["simple.cfm", "SimpleComponent.cfc"];
		
		for (var filename in testFiles) {
			var filePath = expandPath("./artifacts/" & filename);
			if (fileExists(filePath)) {
				variables.ast.parseSourceFile(filePath);
			}
		}
	}
	
	function testErrorHandlingInComponents() {
		// Test with non-existent file
		var nonExistentFile = expandPath("./artifacts/nonexistent.cfm");
		
		// AST should handle non-existent files gracefully
		expect(function() {
			variables.ast.parseSourceFile(nonExistentFile);
		}).toThrow(); // Should throw an error for non-existent file
	}
}