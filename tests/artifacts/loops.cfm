<cfscript>
	// Loop coverage test
	total = 0;
	
	// For loop
	for (i = 1; i <= 5; i++) {
		total += i;
		echo("Loop iteration: " & i);
	}
	
	// While loop
	counter = 0;
	while (counter < 3) {
		echo("While counter: " & counter);
		counter++;
	}
	
	// For-in loop
	items = ["apple", "banana", "orange"];
	for (item in items) {
		echo("Item: " & item);
		if (item == "banana") {
			continue;
		}
		echo("Processing: " & item);
	}
	
	echo("Total: " & total);
</cfscript>