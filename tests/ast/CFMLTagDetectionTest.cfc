component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" displayname="CFMLTagDetectionTest" {

	function beforeAll() {
		variables.logLevel = "info";
		variables.astCallAnalyzer = new lucee.extension.lcov.ast.AstCallAnalyzer();
	}

	function run() {
		describe("CFML Tag Detection", function() {

			it("should detect include tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "include",
								start: {offset: 200, line: 8},
								attributes: [{
									name: "template",
									value: "test.cfm"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var includeCall = functions[1].calls[1];
				expect(includeCall.type).toBe("CFMLTag");
				expect(includeCall.name).toBe("include:test.cfm");
				expect(includeCall.line).toBe(8);
			});

			it("should detect cfinclude tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "cfinclude",
								start: {offset: 200, line: 8},
								attributes: [{
									name: "template",
									value: "/path/to/file.cfm"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var includeCall = functions[1].calls[1];
				expect(includeCall.type).toBe("CFMLTag");
				expect(includeCall.name).toBe("cfinclude:/path/to/file.cfm");
			});

			it("should detect module tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "module",
								start: {offset: 300, line: 10},
								attributes: [{
									name: "name",
									value: "myCustomTag"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var moduleCall = functions[1].calls[1];
				expect(moduleCall.type).toBe("CFMLTag");
				expect(moduleCall.name).toBe("module:myCustomTag");
			});

			it("should detect cfmodule tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "cfmodule",
								start: {offset: 300, line: 10},
								attributes: [{
									name: "template",
									value: "/customtags/mytag.cfm"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var moduleCall = functions[1].calls[1];
				expect(moduleCall.type).toBe("CFMLTag");
				expect(moduleCall.name).toBe("cfmodule:/customtags/mytag.cfm");
			});

			it("should detect invoke tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "invoke",
								start: {offset: 400, line: 12},
								attributes: [{
									name: "component",
									value: "MyComponent"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var invokeCall = functions[1].calls[1];
				expect(invokeCall.type).toBe("CFMLTag");
				expect(invokeCall.name).toBe("invoke:MyComponent");
			});

			it("should detect cfinvoke tags", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "cfinvoke",
								start: {offset: 400, line: 12},
								attributes: [{
									name: "component",
									value: "com.example.Service"
								}]
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(1);

				var invokeCall = functions[1].calls[1];
				expect(invokeCall.type).toBe("CFMLTag");
				expect(invokeCall.name).toBe("cfinvoke:com.example.Service");
			});

			it("should ignore non-tracked CFML tags like cfset", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "cfset",
								start: {offset: 200, line: 8}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(0, "cfset should not be detected as a call");
			});

			it("should ignore non-tracked CFML tags like cfoutput", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [{
								type: "CFMLTag",
								name: "cfoutput",
								start: {offset: 200, line: 8}
							}]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(0, "cfoutput should not be detected as a call");
			});

			it("should handle multiple CFML tags in a function", function() {
				var ast = {
					body: [{
						type: "function",
						name: "testFunction",
						start: {offset: 100, line: 5},
						end: {offset: 1000, line: 25},
						body: {
							body: [
								{
									type: "CFMLTag",
									name: "include",
									start: {offset: 200, line: 8},
									attributes: [{
										name: "template",
										value: "header.cfm"
									}]
								},
								{
									type: "CFMLTag",
									name: "module",
									start: {offset: 300, line: 10},
									attributes: [{
										name: "name",
										value: "processData"
									}]
								},
								{
									type: "CFMLTag",
									name: "include",
									start: {offset: 400, line: 15},
									attributes: [{
										name: "template",
										value: "footer.cfm"
									}]
								}
							]
						}
					}]
				};

				var functions = variables.astCallAnalyzer.extractFunctions(ast);

				expect(arrayLen(functions)).toBe(1);
				expect(arrayLen(functions[1].calls)).toBe(3);

				expect(functions[1].calls[1].name).toBe("include:header.cfm");
				expect(functions[1].calls[2].name).toBe("module:processData");
				expect(functions[1].calls[3].name).toBe("include:footer.cfm");
			});
		});
	}
}