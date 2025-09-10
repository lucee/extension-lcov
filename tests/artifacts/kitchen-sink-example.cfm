<cfscript>
	// Test runner that exercises all the artifact files
	echo("Testing Coverage Artifacts");
	
	// Test coverage-simple-sequential.cfm
	echo("Simple CFM Test");
	include "coverage-simple-sequential.cfm";
	echo("");
	
	// Test conditional.cfm with different URL parameters
	echo("Conditional CFM Test - Default");
	include "conditional.cfm";
	echo("");
	
	// Test loops.cfm
	echo("Loops CFM Test");
	include "loops.cfm";
	echo("");
	
	// Test functions-example.cfm
	echo("Functions CFM Test");
	include "functions-example.cfm";
	echo("");
	
	// Test exception.cfm
	echo("Exception CFM Test");
	include "exception.cfm";
	echo("");
	
	// Test components
	echo("Component Tests");
	
	// SimpleComponent
	simple = new SimpleComponent();
	echo("SimpleComponent name: " & simple.getName());
	echo("Process numeric: " & simple.processValue(42));
	echo("Process string: " & simple.processValue("hello"));
	info = simple.getInfo();
	echo("Component info: " & serializeJSON(info));
	
	// MathUtils
	math = new MathUtils(3);
	echo("MathUtils precision: " & math.getPrecision());
	echo("Add: " & math.add(1.2345, 2.6789));
	echo("Factorial 5: " & math.factorial(5));
	
	numbers = [1, 2, 3, 4, 5];
	stats = math.arrayStats(numbers);
	echo("Array stats: " & serializeJSON(stats));
	
	// DataProcessor
	processor = new DataProcessor();
	echo("DataProcessor name: " & processor.getName());
	
	try {
		validation = processor.validateInput("test", "string");
		echo("String validation: " & validation);
	} catch (any e) {
		echo("Validation error: " & e.message);
	}
	
	matrix = [[1, 2, 3], [4, -5, 6], [0, 8, 9]];
	processed = processor.processMatrix(matrix);
	echo("Processed matrix: " & serializeJSON(processed));
	
	safeResult = processor.safeProcess("test data");
	echo("Safe process result: " & serializeJSON(safeResult));
	
	echo("Coverage Testing Complete");
</cfscript>