<cfscript>
	// Include basic.cfm 5 times in a single request
	loop times=5 {
		include "basic.cfm";
	}
</cfscript>
