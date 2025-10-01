component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" displayname="ClosureDetectionTest" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer();
	}

	function run() {
		describe("Closure and Lambda Detection", function() {

			it("should detect closure expressions", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "ClosureExpression",
								start: {offset: 200, line: 8}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var closureCall = functions[1].calls[1];
				expect(closureCall.type).toBe("ClosureExpression");
				expect(closureCall.name).toBe("closure");
				expect(closureCall.line).toBe(8);
			});

			it("should detect lambda expressions", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "LambdaExpression",
								start: {offset: 300, line: 10}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var lambdaCall = functions[1].calls[1];
				expect(lambdaCall.type).toBe("LambdaExpression");
				expect(lambdaCall.name).toBe("lambda");
				expect(lambdaCall.line).toBe(10);
			});

			it("should detect multiple closures in a function", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [
								{
									type: "ClosureExpression",
									start: {offset: 200, line: 8}
								},
								{
									type: "ClosureExpression",
									start: {offset: 300, line: 12}
								},
								{
									type: "ClosureExpression",
									start: {offset: 400, line: 16}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(3);

				// All should be closures
				for (var i = 1; i <= 3; i++) {
					expect(functions[1].calls[i].type).toBe("ClosureExpression");
					expect(functions[1].calls[i].name).toBe("closure");
				}
			});

			it("should detect multiple lambdas in a function", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [
								{
									type: "LambdaExpression",
									start: {offset: 200, line: 8}
								},
								{
									type: "LambdaExpression",
									start: {offset: 300, line: 12}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(2);

				// All should be lambdas
				for (var i = 1; i <= 2; i++) {
					expect(functions[1].calls[i].type).toBe("LambdaExpression");
					expect(functions[1].calls[i].name).toBe("lambda");
				}
			});

			it("should detect mixed closures and lambdas", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [
								{
									type: "ClosureExpression",
									start: {offset: 200, line: 8}
								},
								{
									type: "LambdaExpression",
									start: {offset: 300, line: 10}
								},
								{
									type: "ClosureExpression",
									start: {offset: 400, line: 12}
								},
								{
									type: "LambdaExpression",
									start: {offset: 500, line: 14}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(4);

				expect(functions[1].calls[1].type).toBe("ClosureExpression");
				expect(functions[1].calls[2].type).toBe("LambdaExpression");
				expect(functions[1].calls[3].type).toBe("ClosureExpression");
				expect(functions[1].calls[4].type).toBe("LambdaExpression");
			});

			it("should handle closures with proper position tracking", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "ClosureExpression",
								start: {
									offset: 250,
									line: 10
								}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var closureCall = functions[1].calls[1];
				expect(closureCall.position).toBe(250);
				expect(closureCall.line).toBe(10);
			});

			it("should handle closures and lambdas alongside regular function calls", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [
								{
									type: "CallExpression",
									callee: {name: "regularFunction"},
									start: {offset: 150, line: 7}
								},
								{
									type: "ClosureExpression",
									start: {offset: 200, line: 8}
								},
								{
									type: "LambdaExpression",
									start: {offset: 300, line: 10}
								},
								{
									type: "CallExpression",
									callee: {name: "anotherFunction"},
									start: {offset: 400, line: 12}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(4);

				expect(functions[1].calls[1].type).toBe("CallExpression");
				expect(functions[1].calls[1].name).toBe("regularFunction");

				expect(functions[1].calls[2].type).toBe("ClosureExpression");
				expect(functions[1].calls[2].name).toBe("closure");

				expect(functions[1].calls[3].type).toBe("LambdaExpression");
				expect(functions[1].calls[3].name).toBe("lambda");

				expect(functions[1].calls[4].type).toBe("CallExpression");
				expect(functions[1].calls[4].name).toBe("anotherFunction");
			});
		});
	}
}