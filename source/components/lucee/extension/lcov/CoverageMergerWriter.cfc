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
			// Always synchronize stats from canonical files struct
			var files = entry.getFiles();
			var canonicalStats = {};
			// Get the first (and only) file key since per-file results should have exactly one file
			var fileKeys = structKeyArray(files);
			if (arrayLen(fileKeys) == 1) {
				var idx = fileKeys[1];
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
				throw (message="BUG: Expected exactly ONE file entry in per-file result, found " & arrayLen(fileKeys) & " files for canonical index " & canonicalIndex & ". Files keys: " & serializeJSON(fileKeys) & ". Entry: " & serializeJSON(entry));
			}
			// Create a filtered entry containing only data for this specific file
			var sourceFilePath = canonicalStats["path"];
			if (!len(sourceFilePath)) {
				throw(message="BUG: Attempted to write output for canonicalStats with empty path. This should never happen. canonicalStats: " & serializeJSON(canonicalStats));
			}

			// Create a new filtered entry for this specific file
			var filteredEntry = duplicate(entry);

			// Set files to only contain this specific file at index 0
			filteredEntry.files = { 0 = duplicate(canonicalStats) };

			// Filter coverage to only include data for this file index
			var originalCoverage = entry.getCoverage();
			var filteredCoverage = {};
			if (structKeyExists(originalCoverage, idx)) {
				filteredCoverage[0] = duplicate(originalCoverage[idx]);
			}
			filteredEntry.setCoverage(filteredCoverage);

			// Filter fileCoverage array to only include entries for this file
			var originalFileCoverage = entry.getFileCoverage();
			var filteredFileCoverage = [];
			for (var fcEntry in originalFileCoverage) {
				if (structKeyExists(fcEntry, "fileIndex") && fcEntry.fileIndex == idx) {
					var newFcEntry = duplicate(fcEntry);
					newFcEntry.fileIndex = 0; // Remap to 0 since this is now the only file
					arrayAppend(filteredFileCoverage, newFcEntry);
				}
			}
			filteredEntry.setFileCoverage(filteredFileCoverage);

			// Set stats to this file's specific stats
			filteredEntry.stats = duplicate(canonicalStats);

			// Generate filename
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

			// Set outputFilename for downstream consumers
			filteredEntry.setOutputFilename(baseName);

			// Create directory if it doesn't exist
			var outputDirNormalized = arguments.outputDir;
			if (!directoryExists(outputDirNormalized)) {
				directoryCreate(outputDirNormalized, true);
			}
			fileWrite(jsonFilePath, serializeJSON(var=filteredEntry, compact=false));
			arrayAppend(writtenFiles, jsonFilePath);
			if (arguments.verbose) {
				systemOutput("writeMergedResultsToFiles: Wrote source file JSON: " & jsonFileName, true);
			}
		}
		return writtenFiles;
	}

}
