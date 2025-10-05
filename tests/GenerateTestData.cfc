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

	/**
	 * Get the directory where .exl execution log files are generated
	 */
	function getExecutionLogDir() {
		return variables.tempCoverageDir;
	}

	/**
	 * Get the directory where test artifacts are located
	 */
	function getSourceArtifactsDir() {
		return variables.testArtifactsPath;
	}
	/**
	 * Get the directory where generated artifacts are stored
	 * Optionally specify a sub-directory (e.g. "reports") which will be created if it doesn't exist
	 * @subDir Optional sub-directory under the generated artifacts directory
	 * @return The full path to the generated artifacts directory (with trailing slash)
	 */
	function getOutputDir(string subDir = "") {
		var outputPath = variables.generatedArtifactsDir;

		if (len(arguments.subDir)) {
			outputPath &= arguments.subDir & "/";
			if (!directoryExists(outputPath)) {
				directoryCreate(outputPath, true);
			}
		}

		return outputPath;
	}

	/**
	 * Generate .exl execution log files by executing test artifacts
	 * 
	 * @adminPassword The server admin password required to enable ResourceExecutionLog
	 * @fileFilter Optional filter to select specific files (e.g. "kitchen-sink-example.cfm" or "*.cfm")
	 * @executionLogOptions Struct of options to pass to Resource
	 * @return Struct with coverageDir, fileCount, and coverageFiles (array of .exl files)
	 */
	
	function generateExlFilesForArtifacts(required string adminPassword,
		string fileFilter = "",
		struct executionLogOptions = {},
		numeric iterations = 1) {
		// Generate .exl files using ResourceExecutionLog

		// Validate artifacts directory exists
		if (!directoryExists(variables.testArtifactsPath)) {
			throw(
				type = "GenerateTestData.MissingDirectory",
				message = "Artifacts directory does not exist: " & variables.testArtifactsPath
			);
		}

		if (directoryExists(variables.tempCoverageDir)) {
			directoryDelete(variables.tempCoverageDir, true);
		}
		directoryCreate(variables.tempCoverageDir, true);

		var exeLogger = new lucee.extension.lcov.exeLogger(arguments.adminPassword);

		var defaultLogOptions = {
			"unit": "micro",
			"min-time": 0,
			"directory": variables.tempCoverageDir
		};

		var logOptions = structCopy(defaultLogOptions);
		structAppend(logOptions, arguments.executionLogOptions, true);

		// Ensure directory is always set to our temp coverage dir
		logOptions.directory = variables.tempCoverageDir;


		// Execute test artifacts to generate coverage
		var templatePath = contractPath(variables.testArtifactsPath);

		// Get list of files in the directory, loop over them and call internalRequest
		var fileCount = 0;
		var filePattern = len(arguments.fileFilter) ? arguments.fileFilter : "*.cfm";
		var files = getArtifactFiles(filePattern);

		// Enable ResourceExecutionLog
		exeLogger.enableExecutionLog(
			class = "lucee.runtime.engine.ResourceExecutionLog",
			args = logOptions,
			maxlogs = 0
		);

		// Execute each file the specified number of iterations
		for ( var iteration = 1; iteration <= arguments.iterations; iteration++ ) {
			for ( var _file in files ) {
				fileCount += executeArtifactFile( _file, templatePath );
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

	private array function getArtifactFiles(required string filePattern) {
		// Check if pattern contains a path (e.g., "multiple/kitchen-sink-5x.cfm")
		if (find("/", arguments.filePattern) || find("\", arguments.filePattern)) {
			var fullPath = variables.testArtifactsPath & "/" & arguments.filePattern;
			if (fileExists(fullPath)) {
				return [arguments.filePattern];
			}
			throw(
				type = "GenerateTestData.NoMatchingFiles",
				message = "File not found: [#arguments.filePattern#] (full path: #fullPath#)"
			);
		}

		// Use directoryList for simple pattern matching
		var files = directoryList(variables.testArtifactsPath, false, "name", arguments.filePattern);

		if (arrayLen(files) == 0) {
			var availableFiles = directoryList(variables.testArtifactsPath, false, "name", "*.cfm");
			var errorMessage = "No files found matching pattern: [#arguments.filePattern#] in [#variables.testArtifactsPath#]";
			if (arrayLen(availableFiles) > 0) {
				errorMessage &= chr(10) & "Available .cfm files: " & arrayToList(availableFiles, ", ");
			} else {
				errorMessage &= chr(10) & "No .cfm files found in directory";
			}

			throw(
				type = "GenerateTestData.NoMatchingFiles",
				message = errorMessage
			);
		}

		return files;
	}

	private numeric function executeArtifactFile(required string fileName, required string templatePath) {
		var urlArgs = {};
		switch (arguments.fileName) {
			case "conditional.cfm":
				urlArgs = [{ test: "default" }, { test: "test" }];
				break;
			case "exception.cfm":
				urlArgs = [{}];
				break;
			default:
				break;
		}

		var executionCount = 0;
		try {
			if (len(urlArgs) == 0) {
				internalRequest(
					template = arguments.templatePath & "/" & arguments.fileName,
					urls = urlArgs,
					throwonerror = true
				);
				executionCount++;
			} else {
				for (var args in urlArgs) {
					internalRequest(
						template = arguments.templatePath & "/" & arguments.fileName,
						urls = args,
						throwonerror = true
					);
					executionCount++;
				}
			}
		} catch (any e) {
			throw(message="Error with artifact: [#arguments.fileName#] " & e.message, cause=e);
		}

		return executionCount;
	}
}