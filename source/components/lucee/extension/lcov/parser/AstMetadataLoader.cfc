/**
 * Helper component to load AST metadata from individual files
 */
component {

	property name="logger";

	public function init(any logger) {
		variables.logger = arguments.logger ?: new lucee.extension.lcov.Logger( level="none" );
		return this;
	}

	/**
	 * Load AST metadata for a specific file path
	 *
	 * @indexPath Path to ast-metadata.json index file
	 * @filePath The source file path to load metadata for
	 * @return Struct with callTree, executableLineCount, executableLines (or empty struct if not found)
	 */
	public struct function loadMetadataForFile(required string indexPath, required string filePath) {
		var indexDir = getDirectoryFromPath( arguments.indexPath );
		var index = loadIndex( arguments.indexPath );

		if ( structKeyExists( index.files, arguments.filePath ) ) {
			var fileEntry = index.files[arguments.filePath];
			var metadataFilePath = indexDir & "ast/" & fileEntry.metadataFile;

			if ( fileExists( metadataFilePath ) ) {
				var content = fileRead( metadataFilePath );
				return deserializeJSON( content );
			}
		}

		return {};
	}

	/**
	 * Load all AST metadata from index
	 * Returns struct keyed by file path with metadata for each file
	 *
	 * @indexPath Path to ast-metadata.json index file
	 * @return Struct of all metadata
	 */
	public struct function loadAllMetadata(required string indexPath) {
		var indexDir = getDirectoryFromPath( arguments.indexPath );
		var index = loadIndex( arguments.indexPath );
		var metadata = {};

		for ( var filePath in index.files ) {
			var fileEntry = index.files[filePath];
			var metadataFilePath = indexDir & "ast/" & fileEntry.metadataFile;

			if ( fileExists( metadataFilePath ) ) {
				var content = fileRead( metadataFilePath );
				metadata[filePath] = deserializeJSON( content );
			}
		}

		return metadata;
	}

	/**
	 * Load metadata for a file using pre-loaded index (avoids re-parsing index)
	 *
	 * @indexPath Path to ast-metadata.json index file
	 * @index Pre-loaded index struct
	 * @filePath The source file path to load metadata for
	 * @return Struct with callTree, executableLineCount, executableLines (or empty struct if not found)
	 */
	public struct function loadMetadataForFileWithIndex(required string indexPath, required struct index, required string filePath) {
		var indexDir = getDirectoryFromPath( arguments.indexPath );

		if ( structKeyExists( arguments.index.files, arguments.filePath ) ) {
			var fileEntry = arguments.index.files[arguments.filePath];
			var metadataFilePath = indexDir & "ast/" & fileEntry.metadataFile;

			if ( fileExists( metadataFilePath ) ) {
				var content = fileRead( metadataFilePath );
				return deserializeJSON( content );
			}
		}

		return {};
	}

	/**
	 * Load and parse the index file
	 */
	public struct function loadIndex(required string indexPath) {
		if ( !fileExists( arguments.indexPath ) ) {
			return {"files": {}};
		}

		var content = fileRead( arguments.indexPath );
		return deserializeJSON( content );
	}

}
