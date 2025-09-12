component labels="lcov" extends="org.lucee.cfml.test.LuceeTestCase" {

	
	function run( testResults, testbox ) {
		var developComponentNames = getDevelopComponents();

		for ( var _comp in developComponentNames ) {
			describe(title="CoverageComponentFactory.getComponent(#_comp#)", body=function(){

				var testData = [];
				for (var name in variables.developComponentNames) {
					arrayAppend(testData, {name=name, useDevelop=false, options={verbose=true}, expectedUseDevelop=false});
					arrayAppend(testData, {name=name, useDevelop=true, options={verbose=false}, expectedUseDevelop=true});
					//arrayAppend(testData, {name=name, useDevelop="", options={verbose=false}, expectedUseDevelop=""});
				}
				for (var _test in testData) {
					it(title="checking #_comp#, useDevelop=#_test.useDevelop#",
							data = _test,
							body = function( data ) {
						var factory = new lucee.extension.lcov.CoverageComponentFactory().init(data.useDevelop);
						assertComponentMeta(factory, data.name, {options=data.options}, data.expectedUseDevelop);
					});
				};
			});
		};
	}

	private function assertComponentMeta(factory, name, initArgs, overrideUseDevelop) {
		var instance = factory.getComponent(
			name=name,
			initArgs=initArgs,
			overrideUseDevelop=overrideUseDevelop
		);
		var meta = getMetadata(instance);
		expect(meta).toBeStruct();
		expect(meta).toHaveKey("path");
		expect(meta).toHaveKey("fullname");
		expect(meta.type).toBe("component");
		if (overrideUseDevelop) {
			expect(findNoCase("develop", meta.path) > 0).toBeTrue("Component #name# should be from develop path");
		} else {
			expect(findNoCase("develop", meta.path) EQ 0).toBeTrue("Component #name# should be from stable path");
		}
		
	}

	private function getDevelopComponents(){
		var thisTestPath = getDirectoryFromPath(getCurrentTemplatePath());
		var developPath = expandPath(thisTestPath & "..\source\components\lucee\extension\lcov\develop");
		var files = directoryList(developPath, true, "query");
		var componentFiles = [];
		for (var row in files) {
			if (right(row.name, 4) == ".cfc") {
				arrayAppend(componentFiles, row.name);
			}
		}
		if (len(componentFiles) eq 0) {
			throw "No develop components found, wrong path [#developPath#].";
		}
		var developComponentNames = [];
		for (var file in componentFiles) {
			var base = listFirst(file, ".");
			arrayAppend(developComponentNames, base);
		}
		return developComponentNames;
	};

}
