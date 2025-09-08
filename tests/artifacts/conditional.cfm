<cfscript>
	// Conditional coverage test
	value = url.keyExists("test") ? url.test : "default";
	
	if (value == "test") {
		systemOutput("Test branch executed", true);
	} else if (value == "other") {
		systemOutput("Other branch executed", true);
	} else {
		systemOutput("Default branch executed", true);
	}
	
	// Switch statement
	switch (value) {
		case "A":
			result = "Letter A";
			break;
		case "B":
			result = "Letter B";
			break;
		default:
			result = "Unknown";
	}
	
	systemOutput("Switch result: " & result, true);
</cfscript>