<cfscript>
	// Test multi-line function calls to verify timing is not duplicated across lines

	// Single-line function call (baseline)
	singleLineResult = someFunction(arg1="value1", arg2="value2", arg3="value3");

	// Multi-line function call (should have same timing as single-line, NOT 5× duplication)
	multiLineResult = someFunction(
		arg1="value1",
		arg2="value2",
		arg3="value3"
	);

	// Another multi-line call with more lines
	anotherMultiLineResult = someFunction(
		arg1="value1",
		arg2="value2",
		arg3="value3",
		arg4="value4",
		arg5="value5",
		arg6="value6"
	);

	// Multi-line array literal
	myArray = [
		"item1",
		"item2",
		"item3",
		"item4"
	];

	// Multi-line struct literal
	myStruct = {
		key1: "value1",
		key2: "value2",
		key3: "value3",
		key4: "value4"
	};

	// Execute multiple times to get consistent timing data
	for (i = 1; i <= 10; i++) {
		singleLineResult = someFunction(arg1="value1", arg2="value2", arg3="value3");

		multiLineResult = someFunction(
			arg1="value1",
			arg2="value2",
			arg3="value3"
		);
	}

	function someFunction(
		required string arg1,
		required string arg2,
		required string arg3,
		string arg4="",
		string arg5="",
		string arg6=""
	) {
		// Simulate some work
		sleep( 3 );
		var result = "";
		for (var i = 1; i <= 10; i++) {
			result &= arguments.arg1 & arguments.arg2 & arguments.arg3;
		}
		return result;
	}

	writeOutput("Multi-line timing test completed");
</cfscript>
