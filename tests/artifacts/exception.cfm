<cfscript>
	// Exception handling coverage test
	
	writeOutput("Starting exception test<br>");
	
	// Try-catch with different exception types
	try {
		writeOutput("Inside try block<br>");
		value = url.keyExists("error") ? url.error : "none";
		
		if (value == "throw") {
			throw(type="CustomError", message="Intentional error");
		} else if (value == "divide") {
			result = 10 / 0;
		} else {
			writeOutput("No error path<br>");
		}
		
		writeOutput("End of try block<br>");
		
	} catch (CustomError e) {
		writeOutput("Caught custom error: " & e.message & "<br>");
		rethrow;
	} catch (any e) {
		writeOutput("Caught general error: " & e.message & "<br>");
	} finally {
		writeOutput("Finally block executed<br>");
	}
	
	// Nested try-catch
	try {
		try {
			if (url.keyExists("nested")) {
				throw(type="NestedError", message="Nested exception");
			}
			writeOutput("Inner try completed<br>");
		} catch (NestedError e) {
			writeOutput("Inner catch: " & e.message & "<br>");
			throw(type="RethrowError", message="Rethrowing", cause=e);
		}
	} catch (any e) {
		writeOutput("Outer catch: " & e.message & "<br>");
		if (structKeyExists(e, "cause")) {
			writeOutput("Original cause: " & e.cause.message & "<br>");
		}
	}
	
	writeOutput("Exception test completed<br>");
</cfscript>