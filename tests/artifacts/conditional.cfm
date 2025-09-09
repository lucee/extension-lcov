<cfscript>
	// Conditional coverage test
	value = url.keyExists("test") ? url.test : "default";
	
	if (value == "test") {
		echo("Test branch executed");
	} else if (value == "other") {
		echo("Other branch executed");
	} else {
		sleep(7); // simulate some processing time
		echo("Default branch executed");
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
	
	echo("Switch result: " & result);
</cfscript>