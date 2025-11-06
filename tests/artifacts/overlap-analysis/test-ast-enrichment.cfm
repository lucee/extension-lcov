<cfscript>
// Test that AST enrichment works

// Create a simple test file
testCode = '
<cfscript>
function testFunc() {
	return 42;
}
result = testFunc();
</cfscript>
';

testFile = expandPath( "./test-enrichment-sample.cfm" );
fileWrite( testFile, testCode );

// Extract metadata using AstMetadataExtractor
logger = new lucee.extension.lcov.Logger( level="info" );
extractor = new lucee.extension.lcov.ast.AstMetadataExtractor( logger=logger );
astParserHelper = new lucee.extension.lcov.parser.AstParserHelper( logger=logger );

ast = astParserHelper.parseFileAst( testFile, testCode );
metadata = extractor.extractMetadata( ast, testFile );

systemOutput( "=== AST Metadata Extraction Test ===" & chr(10), true );
systemOutput( chr(10) & "CallTree entries: #structCount(metadata.callTree)#" & chr(10), true );
systemOutput( "AST nodes: #structCount(metadata.astNodes)#" & chr(10), true );
systemOutput( "Executable lines: #metadata.executableLineCount#" & chr(10), true );

systemOutput( chr(10) & "=== AST Nodes (with type info) ===" & chr(10), true );
for ( key in metadata.astNodes ) {
	node = metadata.astNodes[key];
	systemOutput( "  #key#: type=#node.astNodeType#, isBlock=#node.isBlock#, tagName=#node.tagName#" & chr(10), true );
}

systemOutput( chr(10) & "=== CallTree (function calls) ===" & chr(10), true );
for ( key in metadata.callTree ) {
	call = metadata.callTree[key];
	systemOutput( "  #key#: #call.functionName#(), astNodeType=#call.astNodeType#, isBlock=#call.isBlock#" & chr(10), true );
}

// Clean up
fileDelete( testFile );

systemOutput( chr(10) & "SUCCESS: AST enrichment working!" & chr(10), true );
</cfscript>
