try {
	var testFile = expandPath("./examples.cfc");
	systemOutput("File: " & testFile & chr(10));
	systemOutput("File exists: " & fileExists(testFile) & chr(10));
	
	var ast = astFromPath(testFile);
	systemOutput("AST type: " & getMetadata(ast).name & chr(10));
	systemOutput("AST is struct: " & isStruct(ast) & chr(10));
	
	if (isStruct(ast)) {
		systemOutput("AST keys: " & structKeyList(ast) & chr(10));
	}
	
} catch (any e) {
	systemOutput("ERROR: " & e.message & chr(10));
	systemOutput("Detail: " & (e.detail ?: "none") & chr(10));
	if (structKeyExists(e, "cause") && !isNull(e.cause)) {
		systemOutput("Cause: " & e.cause.toString() & chr(10));
	}
}
