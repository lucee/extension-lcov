// Use astFromPath - the proper Lucee function
var testFile = expandPath("./examples.cfc");
systemOutput("Analyzing: " & testFile & chr(10) & chr(10));

var ast = astFromPath(testFile);

// Helper to dump specific node types we care about
function findArrayAccess(node, depth = 0, results = []) {
	if (isStruct(node)) {
		var indent = repeatString("  ", depth);
		
		// Look for array/struct access patterns
		if (structKeyExists(node, "type")) {
			var nodeType = node.type;
			
			// Member expression is likely what we want
			if (nodeType == "MemberExpression" || nodeType == "member" || 
			    nodeType == "ArrayAccess" || nodeType == "IndexExpression") {
				systemOutput(indent & "Found: " & nodeType & chr(10));
				if (structKeyExists(node, "object")) {
					systemOutput(indent & "  object: " & (isSimpleValue(node.object) ? node.object : node.object.type ?: "complex") & chr(10));
				}
				if (structKeyExists(node, "property")) {
					systemOutput(indent & "  property: " & (isSimpleValue(node.property) ? node.property : node.property.type ?: "complex") & chr(10));
				}
			}
		}
		
		// Recurse through all struct keys
		cfloop(collection=node, item="local.key") {
			if (!isSimpleValue(node[key])) {
				findArrayAccess(node[key], depth + 1, results);
			}
		}
	} else if (isArray(node)) {
		cfloop(array=node, item="local.item") {
			findArrayAccess(item, depth + 1, results);
		}
	}
	
	return results;
}

findArrayAccess(ast);
systemOutput(chr(10) & "Done!" & chr(10));
