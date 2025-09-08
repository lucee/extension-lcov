<cfscript>
	// Loop coverage test
	total = 0;
	
	// For loop
	for (i = 1; i <= 5; i++) {
		total += i;
		systemOutput("Loop iteration: " & i, true);
	}
	
	// While loop
	counter = 0;
	while (counter < 3) {
		systemOutput("While counter: " & counter, true);
		counter++;
	}
	
	// For-in loop
	items = ["apple", "banana", "orange"];
	for (item in items) {
		systemOutput("Item: " & item, true);
		if (item == "banana") {
			continue;
		}
		systemOutput("Processing: " & item, true);
	}
	
	systemOutput("Total: " & total, true);
</cfscript>