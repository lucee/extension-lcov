/**
 * Component responsible for generating LCOV format output
 */
component {

	/**
	 * Initialize the LCOV writer with options
	 * @options Configuration options struct (optional)
	 */
	public function init(required Logger logger, struct options = {}) {
		variables.logger = arguments.logger;
		variables.options = arguments.options;
		return this;
	}

	/**
	 * Build LCOV format content from file coverage data
	 *
	 * Expected fileCoverage structure (from CoverageMerger.mergeResultsByFile):
	 * {
	 *   files: {
	 *     "0": { path: "/path/to/file1.cfm", linesFound: 5, linesHit: 3, ... },
	 *     "1": { path: "/path/to/file2.cfm", linesFound: 8, linesHit: 2, ... }
	 *   },
	 *   coverage: {
	 *     "/path/to/file1.cfm": { "1": [1, 50], "2": [2, 75], ... },
	 *     "/path/to/file2.cfm": { "1": [0, 0], "3": [1, 30], ... }
	 *   }
	 * }
	 *
	 * Note: files keyed by numeric indices, coverage keyed by file paths
	 *
	 * @fileCoverage Struct containing files and coverage data
	 * @useRelativePath Whether to convert paths to relative format
	 * @return String containing LCOV format content
	 */
	public string function buildLCOV(required struct fileCoverage, boolean useRelativePath = false) {
		variables.logger.debug("Building LCOV format with " & structCount(arguments.fileCoverage.files) & " files");
		
		var lcovLines = [];
		var files = arguments.fileCoverage.files;
		var coverage = arguments.fileCoverage.coverage;

		for (var file in files) {
			var originalFilePath = files[file].path;
			var filePath = originalFilePath;

			// Apply relative path conversion if requested
			if (arguments.useRelativePath) {
				try {
					var fileUtils = new lucee.extension.lcov.reporter.FileUtils();
					filePath = fileUtils.safeContractPath(filePath);
					variables.logger.debug("Converted path to relative: " & filePath);
				} catch (any e) {
					// If contractPath fails, use original path
					filePath = originalFilePath;
					variables.logger.debug("Failed to convert path, using original: " & filePath);
				}
			}

			arrayAppend(lcovLines, "SF:" & filePath);
			if (!structKeyExists(coverage, originalFilePath)) {
				throw("buildLCOV: No coverage data found for file [" & originalFilePath & "]");
			}
			var data = coverage[originalFilePath];
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

			variables.logger.debug("Processed file: " & filePath & " (LF:" & linesFoundValue & ", LH:" & linesHit & ")");
		}

		var lcovContent = arrayToList(lcovLines, chr(10));
		variables.logger.debug("Generated LCOV content: " & len(lcovContent) & " characters");
		
		return lcovContent;
	}
}