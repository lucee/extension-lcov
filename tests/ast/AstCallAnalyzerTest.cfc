component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" displayname="AstCallAnalyzerTest" {

	function beforeAll() {
		variables.testDataGenerator = new "../GenerateTestData"(testName="AstCallAnalyzerTest");
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer();
	}

	function run() {
		describe("AstCallAnalyzer", function() {

			it("should extract function definitions from AST", function() {
				// Create a simple AST structure
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 500, line: 15},
						params: [
							{name: "arg1", type: "string", required: true},
							{name: "arg2", type: "numeric", required: false}
						],
						body: {}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(functions).toBeArray();
				expect(arrayLen(functions)).toBe(1);

				var func = functions[1];
				expect(func.name).toBe("testFunction");
				expect(func.startPos).toBe(100);
				expect(func.endPos).toBe(500);
				expect(func.startLine).toBe(5);
				expect(func.endLine).toBe(15);
				expect(arrayLen(func.parameters)).toBe(2);
			});

			it("should extract nested functions", function() {
				var ast = {
					body: [{
						type: "function",
						name: "outerFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "function",
								name: "innerFunction",
								start: {offset: 200, line: 8},
								end: {offset: 400, line: 12}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(2);

				// Check outer function
				var outer = functions[1];
				expect(outer.name).toBe("outerFunction");
				expect(outer.parentScope).toBe("");
				expect(outer.fullName).toBe("outerFunction");

				// Check inner function
				var inner = functions[2];
				expect(inner.name).toBe("innerFunction");
				expect(inner.parentScope).toBe("outerFunction");
				expect(inner.fullName).toBe("outerFunction.innerFunction");
			});

			it("should find function calls within functions", function() {
				var ast = {
					body: [{
						type: "function",
						name: "callerFunction",
						start: {offset: 100, line: 5},
						end: {offset: 500, line: 20},
						body: {
							body: [
								{
									type: "CallExpression",
									callee: {name: "doSomething"},
									start: {offset: 150, line: 7}
								},
								{
									type: "CallExpression",
									callee: {name: "doSomethingElse"},
									start: {offset: 250, line: 10}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);
				var func = functions[1];

				expect(func.name).toBe("callerFunction");
				expect(arrayLen(func.calls)).toBe(2);
				expect(func.calls[1].name).toBe("doSomething");
				expect(func.calls[2].name).toBe("doSomethingElse");
			});

			it("should handle component methods", function() {
				var ast = {
					body: [{
						type: "component",
						name: "TestComponent",
						body: [
							{
								type: "function",
								name: "init",
								start: {offset: 100, line: 3},
								end: {offset: 200, line: 6},
								access: "public",
								returnType: "TestComponent"
							},
							{
								type: "function",
								name: "privateMethod",
								start: {offset: 250, line: 8},
								end: {offset: 400, line: 15},
								access: "private",
								returnType: "void"
							}
						]
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(2);

				var initFunc = functions[1];
				expect(initFunc.name).toBe("init");
				expect(initFunc.parentScope).toBe("TestComponent");
				expect(initFunc.fullName).toBe("TestComponent.init");
				expect(initFunc.isPublic).toBeTrue();
				expect(initFunc.returnType).toBe("TestComponent");

				var privateFunc = functions[2];
				expect(privateFunc.name).toBe("privateMethod");
				expect(privateFunc.isPublic).toBeFalse();
			});

			it("should find containing function for a position", function() {
				var functions = [
					{
						name: "outerFunction",
						startPos: 100,
						endPos: 1000
					},
					{
						name: "innerFunction",
						startPos: 200,
						endPos: 400
					},
					{
						name: "anotherFunction",
						startPos: 1100,
						endPos: 1500
					}
				];

				// Position inside innerFunction
				var result = variables.astCallAnalyzer.findContainingFunction(250, functions);
				expect(result.name).toBe("innerFunction");

				// Position inside outerFunction but outside innerFunction
				result = variables.astCallAnalyzer.findContainingFunction(450, functions);
				expect(result.name).toBe("outerFunction");

				// Position outside all functions
				result = variables.astCallAnalyzer.findContainingFunction(50, functions);
				expect(structIsEmpty(result)).toBeTrue();
			});

			it("should build function map with position-based keys", function() {
				var functions = [
					{
						name: "func1",
						startPos: 100,
						endPos: 200
					},
					{
						name: "func2",
						startPos: 300,
						endPos: 400
					}
				];

				var map = variables.astCallAnalyzer.buildFunctionMap(functions);

				expect(structKeyExists(map, "100-200")).toBeTrue();
				expect(structKeyExists(map, "300-400")).toBeTrue();
				expect(map["100-200"].name).toBe("func1");
				expect(map["300-400"].name).toBe("func2");
			});

			it("should handle anonymous functions", function() {
				var ast = {
					body: [{
						type: "FunctionExpression",
						start: {offset: 100, line: 5},
						end: {offset: 200, line: 8}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(functions[1].name).toBe("anonymous");
			});

			it("should extract different types of function calls", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testCalls",
						start: {offset: 100, line: 1},
						end: {offset: 800, line: 30},
						body: {
							body: [
								{
									type: "CallExpression",
									callee: "simpleCall",
									start: {offset: 150, line: 3}
								},
								{
									type: "MemberExpression",
									callee: {
										property: {name: "methodCall"}
									},
									start: {offset: 200, line: 5}
								},
								{
									type: "NewExpression",
									constructor: "MyClass",
									start: {offset: 250, line: 7}
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);
				var func = functions[1];

				expect(arrayLen(func.calls)).toBe(3);
				expect(func.calls[1].name).toBe("simpleCall");
				expect(func.calls[2].name).toBe("methodCall");
				expect(func.calls[3].name).toBe("new MyClass");
			});

		});
	}

	// Leave test artifacts for inspection - no cleanup in afterAll
}