<cfscript>
	files = directoryList(getDirectoryFromPath(getCurrentTemplatePath()));
	for (row in files) {
		echo("<a href=""#listLast(row, "/\")#"">#ListLast(row,"\/")#</a><br/>");
	}	
</cfscript>