/**
 * ExlSectionReader.cfc
 *
 * Reads .exl files using BufferedReader to efficiently parse metadata and files sections.
 * Stops reading once coverage section is reached, returning the byte offset.
 */
component {

	property name="logger" type="any";

	public function init(required any logger) {
		variables.logger = arguments.logger;
		return this;
	}

	/**
	 * Reads metadata and files sections from an .exl file.
	 * Uses BufferedReader for efficient parsing without loading entire file.
	 * @exlPath Path to .exl file
	 * @return struct containing {metadata: array, files: array, coverageStartByte: numeric}
	 */
	public struct function readExlSections(required string exlPath) {
		var section = 0; // 0=metadata, 1=files, 2=coverage
		var emptyLineCount = 0;
		var metadata = [];
		var files = [];
		var coverageStartByte = 0;
		var start = getTickCount();

		try {
			var reader = createObject("java", "java.io.BufferedReader").init(
				createObject("java", "java.io.FileReader").init(arguments.exlPath)
			);

			try {
				var bytesRead = 0;
				var line = "";

				while (true) {
					line = reader.readLine();
					if (isNull(line)) break;

					var lineLength = len(line) + 1; // +1 for newline character

					if (len(line) == 0) {
						emptyLineCount++;
						if (emptyLineCount == 1) {
							section = 1; // Start files section
						} else if (emptyLineCount == 2) {
							// Found start of coverage section
							coverageStartByte = bytesRead + lineLength;
							break; // Stop reading - we have metadata and files
						}
					} else {
						if (section == 0) {
							arrayAppend(metadata, line);
						} else if (section == 1) {
							arrayAppend(files, line);
						}
					}

					bytesRead += lineLength;
				}
			} finally {
				reader.close();
			}

			variables.logger.trace("Parsed metadata and files sections in " & numberFormat(getTickCount() - start) & "ms. Coverage starts at byte " & numberFormat(coverageStartByte));

			return {
				"metadata": metadata,
				"files": files,
				"coverageStartByte": coverageStartByte
			};

		} catch (any e) {
			variables.logger.debug("Error reading file [" & arguments.exlPath & "]: " & e.message);
			// Return empty sections
			return {
				"metadata": [],
				"files": [],
				"coverageStartByte": 0
			};
		}
	}

}
