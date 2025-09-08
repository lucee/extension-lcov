component {
	
	function init() {
		var testDir = getDirectoryFromPath(getCurrentTemplatePath());
		variables.testArtifactsPath = testDir & "artifacts/";
		variables.generatedArtifactsDir = testDir & "artifacts/generated/GenerateTestData/";
		
		// Clean up and create directories
		if (directoryExists(variables.generatedArtifactsDir)) {
			directoryDelete(variables.generatedArtifactsDir, true);
		}
		directoryCreate(variables.generatedArtifactsDir, true);
		
		// Set coverage directory within generated artifacts
		variables.tempCoverageDir = variables.generatedArtifactsDir & "coverage/";
		directoryCreate(variables.tempCoverageDir, true);
		
		return this;
	}
	
	function generateExlFilesForArtifacts(required string adminPassword) {
		// Generate .exl files using ResourceExecutionLog
		
		// Clean coverage directory
		if (directoryExists(variables.tempCoverageDir)) {
			directoryDelete(variables.tempCoverageDir, true);
		}
		directoryCreate(variables.tempCoverageDir, true);
		
		// Create exeLogger instance
		var exeLogger = new lucee.extension.lcov.exeLogger(arguments.adminPassword);
		
		// Enable ResourceExecutionLog
		exeLogger.enableExecutionLog(
			class = "lucee.runtime.engine.ResourceExecutionLog",
			args = {
				"unit": "micro",
				"min-time": 0,
				"directory": variables.tempCoverageDir
			},
			maxlogs = 0
		);
		
		// Execute test artifacts to generate coverage
		var templatePath = contractPath(variables.testArtifactsPath);
		
		// Get list of files in the directory, loop over them and call internalRequest
		var fileCount = 0;
		var files = directoryList(variables.testArtifactsPath, false, "name", "*.cfm");

		for (var _file in files) {
			var urlArgs = {};
			switch (_file) {
				case "conditional.cfm":
					urlArgs = [{ test: "default" }, { test: "test" }];
					break;
				case "exception.cfm":
					urlArgs = [{}];// { error: "throw" }];
					break;
				default:
					break;
			}
			try {
				if (len(urlArgs) == 0) {
					internalRequest(template: templatePath & "/" & _file, url: urlArgs);
					fileCount++;
				} else {
					for (var args in urlArgs) {
						internalRequest(template: templatePath & "/" & _file, url: args);
						fileCount++;
					}
				}
			} catch (any e) {
				throw ( message="error with artifact: [" & _file & "] " & e.message, cause=e );
			}
		}
		
		// Test component instantiation and method calls
		var simple = new artifacts.SimpleComponent();
		simple.getName();
		simple.processValue(42);
		simple.processValue("test");
		simple.getInfo();
		fileCount++;

		var math = new artifacts.MathUtils(2);
		math.add(1.5, 2.5);
		math.factorial(5);
		math.arrayStats([1,2,3,4,5]);
		fileCount++;

		var processor = new artifacts.DataProcessor();
		processor.validateInput("test", "string");
		processor.processMatrix([[1,2],[3,4]]);
		processor.safeProcess("test data");
		fileCount++;
		
		// Disable ResourceExecutionLog
		exeLogger.disableExecutionLog(class: "lucee.runtime.engine.ResourceExecutionLog");
		
		// Return info about what was generated
		return {
			coverageDir: variables.tempCoverageDir,
			fileCount: fileCount,
			coverageFiles: directoryList(variables.tempCoverageDir, false, "name", "*.exl")
		};
	}
	
	function getCoverageDir() {
		return variables.tempCoverageDir;
	}
	
	function getArtifactsPath() {
		return variables.testArtifactsPath;
	}
	
	function getGeneratedArtifactsDir() {
		return variables.generatedArtifactsDir;
	}
}