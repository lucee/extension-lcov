<cfscript>
	// Exception handling coverage test
	
	echo("Starting exception test");
	
	// Try-catch with different exception types
	try {
		echo("Inside try block");
		value = url.keyExists("error") ? url.error : "none";
		
		if (value == "throw") {
			throw(type="CustomError", message="Intentional error");
		} else if (value == "divide") {
			result = 10 / 0;
		} else {
			echo("No error path");
		}
		
		echo("End of try block");
		
	} catch (CustomError e) {
		echo("Caught custom error: " & e.message);
		rethrow;
	} catch (any e) {
		echo("Caught general error: " & e.message);
	} finally {
		echo("Finally block executed");
	}
	
	// Nested try-catch
	try {
		try {
			if (url.keyExists("nested")) {
				throw(type="NestedError", message="Nested exception");
			}
			echo("Inner try completed");
		} catch (NestedError e) {
			echo("Inner catch: " & e.message);
			throw(type="RethrowError", message="Rethrowing", cause=e);
		}
	} catch (any e) {
		echo("Outer catch: " & e.message);
		if (structKeyExists(e, "cause")) {
			echo("Original cause: " & e.cause.message);
		}
	}
	
	echo("Exception test completed");
</cfscript>