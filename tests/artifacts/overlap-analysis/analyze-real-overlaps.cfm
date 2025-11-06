<cfscript>
// Create a simple file with known overlaps and analyze it
testCode = '
<cfscript>
function outer() {
	var result = inner();
	return result + 10;
}

function inner() {
	return 42;
}

result = outer();
</cfscript>
';

// Write test file
testFile = expandPath( "./test-overlap-sample.cfm" );
fileWrite( testFile, testCode );

// Get AST
ast = astFromPath( testFile );

systemOutput( "=== AST for test file ===" & chr(10), true );
systemOutput( serializeJSON( ast, true ) & chr(10), true );

// Also analyze what blocks would be in the execution log
systemOutput( chr(10) & "=== Expected execution blocks ===" & chr(10), true );
systemOutput( "1. <cfscript> tag: position 1 to " & len(testCode) & chr(10), true );
systemOutput( "2. function outer(): starts around 'function outer()'" & chr(10), true );
systemOutput( "3. function inner(): starts around 'function inner()'" & chr(10), true  );
systemOutput( "4. Call to inner() inside outer(): overlaps with outer function body" & chr(10), true );
systemOutput( "5. Call to outer(): overlaps with <cfscript> block" & chr(10), true );

// Clean up
fileDelete( testFile );
</cfscript>
