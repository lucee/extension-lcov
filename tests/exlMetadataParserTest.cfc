component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {
	
	function beforeAll() {
		variables.utils = new lucee.extension.lcov.codeCoverageUtils();
	}
	
	function testParseMetadata() {
		// Test parseMetadata with array of key:value strings
		var metadataArray = [
			"context-path:",
			"remote-user:",
			"remote-addr:192.168.178.20",
			"remote-host:zac-dell",
			"script-name:/testAdditional/artifacts/functions.cfm",
			"server-name:localhost",
			"protocol:HTTP/1.1",
			"server-port:80",
			"path-info:",
			"query-string:",
			"unit:?s",
			"min-time-nano:0",
			"execution-time:12880"
		];
		
		var parsed = variables.utils.parseMetadata(metadataArray);
		
		expect(parsed["remote-addr"]).toBe("192.168.178.20", "Should parse remote address");
		expect(parsed["script-name"]).toBe("/testAdditional/artifacts/functions.cfm", "Should parse script name");
		expect(parsed["server-name"]).toBe("localhost", "Should parse server name");
		expect(parsed["execution-time"]).toBe("12880", "Should parse execution time");
		expect(parsed.unit).toBe("?s", "Should parse time unit");
	}
	
	function testParseMetadataMinimal() {
		// Test with minimal metadata array
		var minimalMetadataArray = ["execution-time:1000"];
		
		var parsed = variables.utils.parseMetadata(minimalMetadataArray);
		
		expect(parsed["execution-time"]).toBe("1000", "Should parse execution time");
		expect(parsed).toHaveLength(1, "Should only have one key in minimal metadata");
	}

	function testParseMetadataInvalid() {
		// Test with invalid metadata entries
		var invalidMetadata = ["no colons or valid entries", "another invalid entry"];
		
		var parsed = variables.utils.parseMetadata(invalidMetadata);
		
		expect(parsed).toBeStruct();
		expect(parsed).toBeEmpty("Parsed metadata should be empty struct for invalid entries");
	}
	
	function testParseMetadataEmpty() {
		// Test with empty metadata array
		var emptyMetadata = [];
		
		var parsed = variables.utils.parseMetadata(emptyMetadata);
		
		expect(parsed).toBeStruct();
		expect(parsed).toBeEmpty("Parsed metadata should be empty struct");
	}
}