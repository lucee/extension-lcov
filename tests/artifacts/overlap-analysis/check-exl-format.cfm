<cfscript>
// Check what info we get from the execution log

// Look at one of the existing .exl files
exlFile = expandPath( "../misParse/1/140-0A955C3C-211A-4F3B-B46A09DD47838AFD.exl" );

if ( fileExists( exlFile ) ) {
	// Read first few lines
	lines = fileReadArray( exlFile );
	
	systemOutput( "=== Execution Log Format ===" & chr(10), true );
	systemOutput( "File: #exlFile#" & chr(10), true );
	systemOutput( "Total lines: #arrayLen(lines)#" & chr(10), true );
	systemOutput( chr(10) & "First 10 lines:" & chr(10), true );
	
	for ( i = 1; i <= min(10, arrayLen(lines)); i++ ) {
		systemOutput( "Line #i#: #lines[i]#" & chr(10), true );
	}
	
	systemOutput( chr(10) & "=== Format breakdown ===" & chr(10), true );
	systemOutput( "Each line contains tab-separated values:" & chr(10), true );
	systemOutput( "  1. File index" & chr(10), true );
	systemOutput( "  2. Start position (character offset)" & chr(10), true );
	systemOutput( "  3. End position (character offset)" & chr(10), true );
	systemOutput( "  4. Execution time (microseconds)" & chr(10), true );
	systemOutput( chr(10), true );
	systemOutput( "MISSING from .exl:" & chr(10), true );
	systemOutput( "  - AST node type (CallExpression, CFMLTag, etc.)" & chr(10), true );
	systemOutput( "  - Whether it's a container or executable block" & chr(10), true );
	systemOutput( "  - Function name (for calls)" & chr(10), true );
	systemOutput( "  - Tag name (for CFMLTag blocks)" & chr(10), true );
} else {
	systemOutput( "File not found: #exlFile#" & chr(10), true );
}
</cfscript>
