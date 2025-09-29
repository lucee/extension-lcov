component {
	
	function init(
		string testName = "GenerateTestData", 
		string artifactsSubFolder = "") {
		var testDir = getDirectoryFromPath(getCurrentTemplatePath());
		variables.testArtifactsPath = testDir & "artifacts/";
		if (len(artifactsSubFolder)) {
			variables.testArtifactsPath &= artifactsSubFolder & "/";
		}
		
		// Create directory under artifacts/generated based on test name
		variables.generatedArtifactsDir = testDir & "generated-artifacts/" & arguments.testName & "/";
		
		// Clean up from previous runs and create directories
		if (directoryExists(variables.generatedArtifactsDir)) {
			directoryDelete(variables.generatedArtifactsDir, true);
		}
		directoryCreate(variables.generatedArtifactsDir, true);
		
		// Set coverage directory within generated artifacts
		variables.tempCoverageDir = variables.generatedArtifactsDir & "raw/";
		directoryCreate(variables.tempCoverageDir, true);
		
		return this;
	}
	
	function generateExlFilesForArtifacts(required string adminPassword, 
		string fileFilter = "", 
		struct executionLogOptions = {}) {
		// Generate .exl files using ResourceExecutionLog

		// Validate artifacts directory exists
		if (!directoryExists(variables.testArtifactsPath)) {
			throw(
				type = "GenerateTestData.MissingDirectory",
				message = "Artifacts directory does not exist: " & variables.testArtifactsPath
			);
		}

		// Clean coverage directory
		if (directoryExists(variables.tempCoverageDir)) {
			directoryDelete(variables.tempCoverageDir, true);
		}
		directoryCreate(variables.tempCoverageDir, true);

		// Create exeLogger instance
		var exeLogger = new lucee.extension.lcov.exeLogger(arguments.adminPassword);

		// Default execution log options
		var defaultLogOptions = {
			"unit": "micro",
			"min-time": 0,
			"directory": variables.tempCoverageDir
		};

		// Merge custom options with defaults
		var logOptions = structCopy(defaultLogOptions);
		structAppend(logOptions, arguments.executionLogOptions, true);

		// Ensure directory is always set to our temp coverage dir
		logOptions.directory = variables.tempCoverageDir;

		// Enable ResourceExecutionLog
		exeLogger.enableExecutionLog(
			class = "lucee.runtime.engine.ResourceExecutionLog",
			args = logOptions,
			maxlogs = 0
		);

		// Execute test artifacts to generate coverage
		var templatePath = contractPath(variables.testArtifactsPath);

		// Get list of files in the directory, loop over them and call internalRequest
		var fileCount = 0;
		var filePattern = len(arguments.fileFilter) ? arguments.fileFilter : "*.cfm";
		var files = directoryList(variables.testArtifactsPath, false, "name", filePattern);

		// Validate that we found files matching the pattern
		if (arrayLen(files) == 0) {
			// Provide helpful error message
			var availableFiles = directoryList(variables.testArtifactsPath, false, "name", "*.cfm");
			var errorMessage = "No files found matching pattern: " & filePattern & " in " & variables.testArtifactsPath;
			if (arrayLen(availableFiles) > 0) {
				errorMessage &= chr(10) & "Available .cfm files: " & arrayToList(availableFiles, ", ");
			} else {
				errorMessage &= chr(10) & "No .cfm files found in directory";
			}

			// Disable execution log before throwing
			exeLogger.disableExecutionLog(class: "lucee.runtime.engine.ResourceExecutionLog");

			throw(
				type = "GenerateTestData.NoMatchingFiles",
				message = errorMessage
			);
		}

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
					internalRequest(
						template = templatePath & "/" & _file,
						urls = urlArgs,
						throwonerror = true
					);
					fileCount++;
				} else {
					for (var args in urlArgs) {
						internalRequest(
							template = templatePath & "/" & _file,
							urls = args,
							throwonerror = true
						);
						fileCount++;
					}
				}
			} catch (any e) {
				throw ( message="error with artifact: [" & _file & "] " & e.message, cause=e );
			}
		}
		
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