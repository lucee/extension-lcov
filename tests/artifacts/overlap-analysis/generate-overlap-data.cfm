<cfscript>
// Generate execution log with overlapping blocks
lcovStartLogging();

// Simple nested example - function call inside a block
function outerFunction() {
	var x = 1;
	var result = innerFunction();
	return result;
}

function innerFunction() {
	return 42;
}

// Execute to generate overlaps
result = outerFunction();

lcovStopLogging();

// Generate reports
outputDir = expandPath( "./output/" );
if ( !directoryExists( outputDir ) ) {
	directoryCreate( outputDir );
}

lcovGenerateJson( outputDir=outputDir );

systemOutput( "Generated overlap data in: #outputDir#" & chr(10), true );
</cfscript>
