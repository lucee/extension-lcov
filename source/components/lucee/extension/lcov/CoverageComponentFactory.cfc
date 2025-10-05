
component accessors="true" {

	property name="useDevelop" access="public" default="false";

	/**
	 * Constructor/init method for CoverageComponentFactory
	 * @useDevelop [optional boolean] - if provided, sets the global useDevelop property
	 */
	public any function init(boolean useDevelop) {
		if (structKeyExists(arguments, "useDevelop")) {
			variables.useDevelop = arguments.useDevelop;
		}
		return this;
	}

	/**
	 * Get a component (develop or stable) by name, passing init args if provided
	 * @name The name of the component (e.g. "CoverageBlockProcessor", "CoverageStats", "ast.ExecutableLineCounter")
	 * @initArgs Optional struct of arguments to pass to init()
	 * @overrideUseDevelop [optional] - override the global flag for this call
	 */
	public any function getComponent(required string name, struct initArgs = {}, boolean overrideUseDevelop) {
		var useDev = arguments.overrideUseDevelop ?: variables.useDevelop;
		var path = useDev ? "develop." & arguments.name : "lucee.extension.lcov." & arguments.name;

		// Provide default logger if not supplied and component needs one
		if (!structKeyExists( arguments.initArgs, "logger" )) {
			arguments.initArgs.logger = new lucee.extension.lcov.Logger( level="none" );
		}

		return new "#path#"( argumentCollection=initArgs );
	}

}
