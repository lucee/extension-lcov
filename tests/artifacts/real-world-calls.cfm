<cfscript>
	// Test file with real-world function calls that MUST be detected

	// Line 4: Constructor call (new)
	obj1 = new SimpleComponent();

	// Line 7: Another constructor with package path
	obj2 = new lucee.extension.lcov.Logger( level="none" );

	// Line 10: Constructor with arguments
	obj3 = new MathUtils( 5 );

	// Line 13: Method call on factory
	factory = new lucee.extension.lcov.CoverageComponentFactory();
	component = factory.getComponent( name="CoverageBlockProcessor" );

	// Line 17: Simple method call (not chained - too complex)
	stats = factory.getComponent( name="CoverageStats" );

	echo("Done");
</cfscript>
