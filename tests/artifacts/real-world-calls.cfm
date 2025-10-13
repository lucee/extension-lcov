<cfscript>
	// Test file with real-world function calls that MUST be detected

	// Line 4: Constructor call (new)
	obj1 = new SimpleComponent();

	// Line 7: Another constructor with package path
	obj2 = new lucee.extension.lcov.Logger( level="none" );

	// Line 10: Constructor with arguments
	obj3 = new MathUtils( 5 );

	// Line 13: Method call on processor
	logger = new lucee.extension.lcov.Logger( level="none" );
	component = new lucee.extension.lcov.coverage.CoverageBlockProcessor( logger=logger );

	// Line 17: Simple method call (not chained - too complex)
	stats = new lucee.extension.lcov.CoverageStats( logger=logger );

	echo("Done");
</cfscript>
