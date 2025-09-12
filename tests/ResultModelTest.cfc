component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

	function run() {
		describe("Result model API", function() {
			it("should set and get metadata and stats via accessors", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.setMetadata({"script-name":"test.cfm","generated-by":"test","timestamp":123456});
				Result.setStats({totalLinesFound:10,totalLinesHit:7,totalLinesSource:10,totalExecutions:1,totalExecutionTime:42});
				Result.setFiles({});
				Result.setCoverage({});
				expect(Result.getMetadataProperty("script-name")).toBe("test.cfm");
				expect(Result.getStatsProperty("totalLinesFound")).toBe(10);
				Result.validate();
			});

			it("should get all file paths from files struct", function() {
				var Result = new lucee.extension.lcov.model.result();
				   Result.setFiles({0:{path:"foo.cfm"},1:{path:"bar.cfm"}});
				   expect(Result.getAllFilePaths()).toBeArray();
				   expect(Result.getAllFilePaths().len()).toBe(2);
			});

			it("should get file stats for a file", function() {
				var Result = new lucee.extension.lcov.model.result();
				   Result.setStats({totalLinesFound:1,totalLinesHit:1,totalLinesSource:1,totalExecutions:1,totalExecutionTime:1});
				   Result.setFileItem(0, {hits:5});
				   expect(Result.getFileItem(0)).toBeStruct();
				   expect(function(){Result.getFileItem(1);}).toThrow();
			});

			it("should get coverage for a file", function() {
				var Result = new lucee.extension.lcov.model.result();
				   Result.setCoverage({0:{cov:1}});
				   expect(Result.getCoverageForFile(0)).toBeStruct();
				   expect(function(){Result.getCoverageForFile(1);}).toThrow();
			});

			it("should get file lines and executable lines", function() {
				var Result = new lucee.extension.lcov.model.result();
				   Result.setFiles({0:{lines:[1,2,3],executableLines:{1:true,2:true}}});
				   expect(Result.getFileLines(0)).toBeArray();
				   expect(Result.getExecutableLines(0)).toBeStruct();
				   expect(function(){Result.getFileLines(1);}).toThrow();
				   expect(function(){Result.getExecutableLines(1);}).toThrow();
			});

			it("should calculate total coverage percent", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.setStats({totalLinesFound:10,totalLinesHit:5,totalLinesSource:10,totalExecutions:1,totalExecutionTime:0});
				expect(Result.getTotalCoveragePercent()).toBe(50);
				Result.setStats({totalLinesFound:0,totalLinesHit:0,totalLinesSource:0,totalExecutions:0,totalExecutionTime:0});
				expect(Result.getTotalCoveragePercent()).toBe(0);
				expect(function(){Result.setStats({});Result.getTotalCoveragePercent();}).toThrow();
			});

			it("should throw for missing metadata/stats property", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.setMetadata({foo:"bar"});
				expect(function(){Result.getMetadataProperty("baz");}).toThrow();
				Result.setStats({foo:1});
				expect(function(){Result.getStatsProperty("baz");}).toThrow();
			});

			it("should init stats with canonical fields", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.initStats();
				var s = Result.getStats();
				expect(s).toHaveKey("totalLinesFound");
				expect(s).toHaveKey("totalLinesHit");
				expect(s).toHaveKey("totalLinesSource");
				expect(s).toHaveKey("totalExecutions");
				expect(s).toHaveKey("totalExecutionTime");
			});

			it("should set and get file item", function() {
				var Result = new lucee.extension.lcov.model.result();
				   Result.setFileItem(0,{lines:[1,2]});
				   expect(Result.getFileItem(0)).toBeStruct();
				   Result.setFileItem(1,{hits:1});
				   expect(Result.getFileItem(1)).toBeStruct();
				   expect(function(){Result.getFileItem(2);}).toThrow();
			});

			it("should serialize to and from JSON", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.setMetadata({foo:"bar"});
				Result.setStats({
					totalLinesFound: 1,
					totalLinesHit: 1,
					totalLinesSource: 1,
					totalExecutions: 1,
					totalExecutionTime: 1
				});
				Result.setFiles({});
				Result.setCoverage({});
				var json = Result.toJson();
				var Result2 = new lucee.extension.lcov.model.result().fromJson(json, false);
				expect(Result2.getMetadata().foo).toBe("bar");
			});

			it("should return instance data as struct", function() {
				var Result = new lucee.extension.lcov.model.result();
				Result.setMetadata({foo:"bar"});
				Result.setStats({totalLinesFound:1,totalLinesHit:1,totalLinesSource:1,totalExecutions:1,totalExecutionTime:1});
				Result.setFiles({});
				Result.setCoverage({});
				var data = Result.getData();
				expect(data).toHaveKey("metadata");
				expect(data).toHaveKey("stats");
				expect(data).toHaveKey("files");
				expect(data).toHaveKey("coverage");
			});

			it("should validate required fields and throw on missing", function() {
				var Result = new lucee.extension.lcov.model.result();
				expect(function(){Result.validate();}).toThrow();
				Result.setMetadata({foo:"bar"});
				Result.setStats({totalLinesFound:1,totalLinesHit:1,totalLinesSource:1,totalExecutions:1,totalExecutionTime:1});
				Result.setFiles({});
				Result.setCoverage({});
				expect(function(){Result.validate();}).notToThrow();
			});
		});
	}
}
