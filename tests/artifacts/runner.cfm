<cfscript>
	// Test runner that exercises all the artifact files
	writeOutput("<h2>Testing Coverage Artifacts</h2>");
	
	// Test simple.cfm
	writeOutput("<h3>Simple CFM Test</h3>");
	include "simple.cfm";
	writeOutput("<br><br>");
	
	// Test conditional.cfm with different URL parameters
	writeOutput("<h3>Conditional CFM Test - Default</h3>");
	include "conditional.cfm";
	writeOutput("<br><br>");
	
	// Test loops.cfm
	writeOutput("<h3>Loops CFM Test</h3>");
	include "loops.cfm";
	writeOutput("<br><br>");
	
	// Test functions.cfm
	writeOutput("<h3>Functions CFM Test</h3>");
	include "functions.cfm";
	writeOutput("<br><br>");
	
	// Test exception.cfm
	writeOutput("<h3>Exception CFM Test</h3>");
	include "exception.cfm";
	writeOutput("<br><br>");
	
	// Test components
	writeOutput("<h3>Component Tests</h3>");
	
	// SimpleComponent
	simple = new SimpleComponent();
	writeOutput("SimpleComponent name: " & simple.getName() & "<br>");
	writeOutput("Process numeric: " & simple.processValue(42) & "<br>");
	writeOutput("Process string: " & simple.processValue("hello") & "<br>");
	info = simple.getInfo();
	writeOutput("Component info: " & serializeJSON(info) & "<br><br>");
	
	// MathUtils
	math = new MathUtils(3);
	writeOutput("MathUtils precision: " & math.getPrecision() & "<br>");
	writeOutput("Add: " & math.add(1.2345, 2.6789) & "<br>");
	writeOutput("Factorial 5: " & math.factorial(5) & "<br>");
	
	numbers = [1, 2, 3, 4, 5];
	stats = math.arrayStats(numbers);
	writeOutput("Array stats: " & serializeJSON(stats) & "<br><br>");
	
	// DataProcessor
	processor = new DataProcessor();
	writeOutput("DataProcessor name: " & processor.getName() & "<br>");
	
	try {
		validation = processor.validateInput("test", "string");
		writeOutput("String validation: " & validation & "<br>");
	} catch (any e) {
		writeOutput("Validation error: " & e.message & "<br>");
	}
	
	matrix = [[1, 2, 3], [4, -5, 6], [0, 8, 9]];
	processed = processor.processMatrix(matrix);
	writeOutput("Processed matrix: " & serializeJSON(processed) & "<br>");
	
	safeResult = processor.safeProcess("test data");
	writeOutput("Safe process result: " & serializeJSON(safeResult) & "<br>");
	
	writeOutput("<h3>Coverage Testing Complete</h3>");
</cfscript>