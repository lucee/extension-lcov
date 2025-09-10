/**
 * Component responsible for generating LCOV format output
 */
component {

	/**
	 * Initialize the LCOV writer with options
	 * @options Configuration options struct (optional)
	 */
	public function init(struct options = {}) {
		// Store options and extract verbose flag
		variables.options = arguments.options;
		variables.verbose = structKeyExists(variables.options, "verbose") ? variables.options.verbose : false;
		return this;
	}

	/**
	 * Private logging function that respects verbose setting
	 * @message The message to log
	 */
	private void function logger(required string message) {
		if (variables.verbose) {
			systemOutput(arguments.message, true);
		}
	}

	/**
	 * Build LCOV format content from file coverage data
	 * @fileCoverage Struct containing files and coverage data
	 * @useRelativePath Whether to convert paths to relative format
	 * @return String containing LCOV format content
	 */
	public string function buildLCOV(required struct fileCoverage, boolean useRelativePath = false) {
		logger("Building LCOV format with " & structCount(arguments.fileCoverage.files) & " files");
		
		var lcovLines = [];
		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;

		for (var file in files) {
			var filePath = files[file].path;
			
			// Apply relative path conversion if requested
			if (arguments.useRelativePath) {
				try {
					filePath = contractPath(filePath);
					logger("Converted path to relative: " & filePath);
				} catch (any e) {
					// If contractPath fails, use original path
					filePath = files[file].path;
					logger("Failed to convert path, using original: " & filePath);
				}
			}

			arrayAppend(lcovLines, "SF:" & filePath);

			var data = coverage[file];
			var lineNumbers = structKeyArray(data);
			arraySort(lineNumbers, "numeric");

			var linesHit = 0;
			for (var line in lineNumbers) {
				var hitCount = data[line][1];
				arrayAppend(lcovLines, "DA:" & line & "," & hitCount);
				if (hitCount > 0) {
					linesHit++;
				}
			}

			var linesFoundValue = structKeyExists(files[file], "linesFound") ? files[file].linesFound : arrayLen(lineNumbers);
			arrayAppend(lcovLines, "LF:" & linesFoundValue);
			arrayAppend(lcovLines, "LH:" & linesHit);
			arrayAppend(lcovLines, "end_of_record");
			
			logger("Processed file: " & filePath & " (LF:" & linesFoundValue & ", LH:" & linesHit & ")");
		}

		var lcovContent = arrayToList(lcovLines, chr(10));
		logger("Generated LCOV content: " & len(lcovContent) & " characters");
		
		return lcovContent;
	}
}