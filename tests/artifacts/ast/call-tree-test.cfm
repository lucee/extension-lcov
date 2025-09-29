<cfscript>
// Call tree test - demonstrates function calls with timing
echo("Starting call tree test" & chr(10));

// Main function that orchestrates everything
function main() {
	var startTime = getTickCount();
	echo("Main function started" & chr(10));

	// Call level 1 functions
	var data = fetchData();
	var processed = processData(data);
	var result = saveResults(processed);

	echo("Main function completed in " & (getTickCount() - startTime) & "ms" & chr(10));
	return result;
}

// Level 1 function: Fetch data
function fetchData() {
	echo("  fetchData: starting" & chr(10));
	sleep(3); // Simulate database query

	// Call level 2 functions
	var rawData = queryDatabase();
	var validated = validateData(rawData);

	echo("  fetchData: completed" & chr(10));
	return validated;
}

// Level 1 function: Process data
function processData(data) {
	echo("  processData: starting" & chr(10));
	sleep(2); // Simulate processing

	// Call level 2 functions
	var transformed = transformData(data);
	var enriched = enrichData(transformed);

	echo("  processData: completed" & chr(10));
	return enriched;
}

// Level 1 function: Save results
function saveResults(data) {
	echo("  saveResults: starting" & chr(10));
	sleep(2); // Simulate save operation

	// Call level 2 function
	var serialized = serializeData(data);
	writeToFile(serialized);

	echo("  saveResults: completed" & chr(10));
	return true;
}

// Level 2 function: Query database
function queryDatabase() {
	echo("    queryDatabase: running" & chr(10));
	sleep(5); // Simulate slow query
	return {
		records: 100,
		data: "raw data from database"
	};
}

// Level 2 function: Validate data
function validateData(rawData) {
	echo("    validateData: running" & chr(10));
	sleep(1); // Simulate validation

	// Call level 3 function
	checkIntegrity(rawData);

	return rawData;
}

// Level 2 function: Transform data
function transformData(data) {
	echo("    transformData: running" & chr(10));
	sleep(3); // Simulate transformation

	// Call level 3 functions
	normalizeData(data);
	cleanData(data);

	return data;
}

// Level 2 function: Enrich data
function enrichData(data) {
	echo("    enrichData: running" & chr(10));
	sleep(2); // Simulate enrichment

	// Call level 3 function
	addMetadata(data);

	return data;
}

// Level 2 function: Serialize data
function serializeData(data) {
	echo("    serializeData: running" & chr(10));
	sleep(1); // Simulate serialization
	return serializeJSON(data);
}

// Level 2 function: Write to file
function writeToFile(serialized) {
	echo("    writeToFile: running" & chr(10));
	sleep(2); // Simulate file write
	return;
}

// Level 3 function: Check integrity
function checkIntegrity(data) {
	echo("      checkIntegrity: running" & chr(10));
	sleep(1); // Simulate check
	return true;
}

// Level 3 function: Normalize data
function normalizeData(data) {
	echo("      normalizeData: running" & chr(10));
	sleep(1); // Simulate normalization
	return;
}

// Level 3 function: Clean data
function cleanData(data) {
	echo("      cleanData: running" & chr(10));
	sleep(1); // Simulate cleaning

	// Recursive call to demonstrate recursion handling
	if (structKeyExists(data, "nested") && isStruct(data.nested)) {
		cleanData(data.nested);
	}

	return;
}

// Level 3 function: Add metadata
function addMetadata(data) {
	echo("      addMetadata: running" & chr(10));
	sleep(1); // Simulate adding metadata
	return;
}

// Execute the main function
executionStart = getTickCount();
result = main();
totalTime = getTickCount() - executionStart;

echo("" & chr(10));
echo("Total execution time: " & totalTime & "ms" & chr(10));
echo("Expected ~24 seconds due to sleep() calls" & chr(10));
echo("" & chr(10));
echo("Call tree structure:" & chr(10));
echo("main()" & chr(10));
echo("  ├── fetchData()" & chr(10));
echo("  │   ├── queryDatabase() [5s]" & chr(10));
echo("  │   └── validateData() [1s]" & chr(10));
echo("  │       └── checkIntegrity() [1s]" & chr(10));
echo("  ├── processData()" & chr(10));
echo("  │   ├── transformData() [3s]" & chr(10));
echo("  │   │   ├── normalizeData() [1s]" & chr(10));
echo("  │   │   └── cleanData() [1s + recursive]" & chr(10));
echo("  │   └── enrichData() [2s]" & chr(10));
echo("  │       └── addMetadata() [1s]" & chr(10));
echo("  └── saveResults()" & chr(10));
echo("      ├── serializeData() [1s]" & chr(10));
echo("      └── writeToFile() [2s]" & chr(10));
</cfscript>