// Quick script to dump AST for double lookup pattern
var code = '
var myArray = [1, 2, 3];
cfloop(array=myArray, index="local.i") {
	if (myArray[i] > 1) {
		echo(myArray[i]);
	}
}
';

var ast = getComponentMetadata("cfml").getParser().toAST(code);

function dumpNode(node, indent = "") {
	if (isStruct(node)) {
		if (structKeyExists(node, "type")) {
			systemOutput(indent & "type: " & node.type & chr(10));
		}
		cfloop(collection=node, item="local.key") {
			if (key != "type" && key != "start" && key != "end" && key != "line") {
				systemOutput(indent & "  " & key & ": ");
				if (isSimpleValue(node[key])) {
					systemOutput(node[key] & chr(10));
				} else if (isArray(node[key])) {
					systemOutput("[array with " & arrayLen(node[key]) & " items]" & chr(10));
					cfloop(array=node[key], index="local.idx") {
						systemOutput(indent & "    [" & idx & "]" & chr(10));
						dumpNode(node[key][idx], indent & "      ");
					}
				} else {
					systemOutput(chr(10));
					dumpNode(node[key], indent & "    ");
				}
			}
		}
	}
}

dumpNode(ast);
