<cfscript>
// Classify AST node types as container vs executable based on the AST we saw

systemOutput( "=== AST Node Classification for Overlapping Blocks ===" & chr(10), true );
systemOutput( chr(10), true );

// From the AST we saw, let's classify nodes:
classifications = {
	// CONTAINER BLOCKS - Don't execute code themselves, just contain other code
	"containers": [
		{type: "CFMLTag", name: "cfscript", reason: "Contains script code but doesn't execute itself"},
		{type: "Program", reason: "Root container for all code"},
		{type: "BlockStatement", reason: "Contains statements but doesn't execute"},
		{type: "FunctionDeclaration", reason: "Defines a function but timing belongs to call sites"}
	],
	
	// EXECUTABLE BLOCKS - Actually run code and should keep their timing
	"executable": [
		{type: "CallExpression", reason: "Actual function call that executes code"},
		{type: "AssignmentExpression", reason: "Executes an assignment"},
		{type: "ReturnStatement", reason: "Executes a return"},
		{type: "BinaryExpression", reason: "Executes an operation like PLUS"},
		{type: "MemberExpression", reason: "Executes property access"}
	],
	
	// LITERALS - Don't execute, just provide values
	"literals": [
		{type: "StringLiteral", reason: "Just a value, no execution"},
		{type: "NumberLiteral", reason: "Just a value, no execution"},
		{type: "BooleanLiteral", reason: "Just a value, no execution"},
		{type: "Identifier", reason: "Just a reference, no execution"}
	]
};

systemOutput( "CONTAINER BLOCKS (timing should go to children):" & chr(10), true );
for ( item in classifications.containers ) {
	systemOutput( "  - #item.type#: #item.reason#" & chr(10), true );
}

systemOutput( chr(10) & "EXECUTABLE BLOCKS (keep their own timing):" & chr(10), true );
for ( item in classifications.executable ) {
	systemOutput( "  - #item.type#: #item.reason#" & chr(10), true );
}

systemOutput( chr(10) & "LITERALS (no timing):" & chr(10), true );
for ( item in classifications.literals ) {
	systemOutput( "  - #item.type#: #item.reason#" & chr(10), true );
}

systemOutput( chr(10) & "=== Real-world overlap example ===" & chr(10), true );
systemOutput( "When we have: <cfscript> result = outer(); </cfscript>" & chr(10), true );
systemOutput( chr(10), true );
systemOutput( "Overlapping blocks:" & chr(10), true );
systemOutput( "  1. <cfscript> (pos 1-142) - CONTAINER" & chr(10), true );
systemOutput( "  2. CallExpression outer() (pos 121-128) - EXECUTABLE" & chr(10), true );
systemOutput( chr(10), true );
systemOutput( "Decision: <cfscript> is a CONTAINER, so its 'own time' should be 0ms" & chr(10), true );
systemOutput( "          All timing should be attributed to the CallExpression" & chr(10), true );
</cfscript>
