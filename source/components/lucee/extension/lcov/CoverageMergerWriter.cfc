/**
 * CoverageMergerWriter.cfc
 *
 * Contains the logic for writing merged coverage results to per-file JSON (and HTML) files.
 * Extracted from CoverageMerger.cfc for separation of concerns.
 */
component accessors=false {

	/**
	 * Write merged results to per-file JSON files (and HTML if needed)
	 * @mergedResults Struct of merged result objects keyed by canonical index
	 * @outputDir Directory to write the file-*.json files to
	 * @verbose Boolean flag for verbose logging
	 * @return Array of written file paths
	 */
	public array function writeMergedResultsToFiles(required struct mergedResults, required string outputDir, boolean verbose = false) {
		var writtenFiles = [];
		for (var canonicalIndex in arguments.mergedResults) {
			var entry = arguments.mergedResults[canonicalIndex];
			var idx = 0;
			// Always synchronize stats from canonical files struct
			var files = entry.getFiles();
			var canonicalStats = {};
			if (structKeyExists(files, idx)) {
				var srcFile = files[idx];
				// Fail fast if any required field is missing
				var requiredFields = ["linesSource","linesFound","linesHit","path","totalExecutions","totalExecutionTime","lines","executableLines"];
				for (var f in requiredFields) {
					if (!structKeyExists(srcFile, f)) {
						throw(message="BUG: Missing required field '" & f & "' in srcFile for canonical index " & canonicalIndex & ". srcFile: " & serializeJSON(srcFile));
					}
				}
				// Copy all required fields exactly, no patching or fallback
				for (var f in requiredFields) {
					canonicalStats[f] = srcFile[f];
				}
			} else {
				throw (message="BUG: Missing expected 'files' struct or entry for canonical index " & canonicalIndex & ". This should never happen. Entry: " & serializeJSON(entry));
			}
			// Overwrite all stats sections with canonicalStats
			entry.setFileItem(idx, duplicate(canonicalStats));
			// TODO is this correct?????
			entry.stats = duplicate(canonicalStats);
			// Always use numeric 0 as the key for 'files' struct
			// Fail fast if any entry has missing/empty path
			var sourceFilePath = canonicalStats["path"];
			if (!len(sourceFilePath)) {
				throw(message="BUG: Attempted to write output for canonicalStats with empty path. This should never happen. canonicalStats: " & serializeJSON(canonicalStats));
			}
			if (structKeyExists(entry, "files")) {
				entry.files[0] = duplicate(canonicalStats);
			} else {
				entry["files"] = { 0 = duplicate(canonicalStats) };
			}
			var sourceDir = getDirectoryFromPath(sourceFilePath);
			var sourceFileName = getFileFromPath(sourceFilePath);
			if (!len(sourceFileName)) {
				throw(message="BUG: Attempted to write output for canonicalStats with missing filename for path: " & sourceFilePath & ". canonicalStats: " & serializeJSON(canonicalStats));
			}
			var dirHash = left(hash(sourceDir, "MD5"), 7);
			var baseName = "file-" & dirHash & "-" & reReplace(sourceFileName, "\\.(cfm|cfc)$", "");
			var jsonFileName = baseName & ".json";
			var htmlFileName = baseName & ".html";
			var jsonFilePath = arguments.outputDir & "/" & jsonFileName;
			// Always set outputFilename (without extension) for downstream consumers (e.g., HTML reporter)
			if (!len(entry.getOutputFilename())) {
				entry.setOutputFilename(baseName);
			}
			fileWrite(jsonFilePath, serializeJSON(var=entry, compact=false));
			arrayAppend(writtenFiles, jsonFilePath);
			if (arguments.verbose) {
				systemOutput("Wrote source file JSON: " & jsonFileName, true);
			}
		}
		return writtenFiles;
	}

}
