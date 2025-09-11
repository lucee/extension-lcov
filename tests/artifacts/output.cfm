<!--this script produceds a query with 100 rows and 3 columns, lots repeated execution log sections -->
<cfscript>
	cols = ['name','age','city'];
	q = queryNew( cols );
	loop times = 10 {
		r = queryAddRow( q );
		for (c in cols) {
			querySetCell( q, c, createUUID(), r );
		}
		sleep(randRange(1,3) );
	}
</cfscript>

<cfoutput query="q">
	#name# - #age# - #city#<br>
</cfoutput>