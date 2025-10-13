/**
 * AstParserHelper.cfc
 *
 * Handles AST parsing with fallback logic and caching.
 * Deals with Lucee LDEV-5839 bug where astFromString() treats .cfc files as StringLiteral.
 */
component {

	property name="logger" type="any";
	property name="astCache" type="struct" default="#{}#";

	public function init(required any logger, struct sharedAstCache) {
		variables.logger = arguments.logger;
		// Use shared AST cache if provided (for parallel processing), otherwise use instance cache
		if (structKeyExists(arguments, "sharedAstCache")) {
			variables.astCache = arguments.sharedAstCache;
		} else {
			variables.astCache = {};
		}
		return this;
	}

	/**
	 * Parses a file's AST with intelligent fallback and caching.
	 * First attempts astFromPath(), falls back to astFromString() if needed.
	 * Handles .cfc file wrapping for LDEV-5839 bug workaround.
	 * @path File path to parse
	 * @fileContent File content (from cache)
	 * @return any AST object
	 */
	public any function parseFileAst(required string path, required string fileContent) {
		// Check AST cache first
		if (structKeyExists(variables.astCache, arguments.path)) {
			return variables.astCache[arguments.path];
		}

		var ast = "";

		// WORKAROUND: astFromString() treats .cfc files as StringLiteral (Lucee bug LDEV-5839)
		// Use astFromPath() which parses .cfc files correctly
		try {
			ast = astFromPath(arguments.path);
		} catch (any e) {
			// astFromPath() can fail with certain files - fall back to astFromString()
			variables.logger.debug("astFromPath failed for [" & arguments.path & "], falling back to astFromString: " & e.message);

			var content = arguments.fileContent;

			// Fix for .cfc files: wrap in cfscript tags if it doesn't contain cfcomponent tag
			if (arguments.path.endsWith(".cfc") && !findNoCase("<" & "cfcomponent", content)) {
				content = "<" & "cfscript>" & content & "</" & "cfscript>";
			}

			ast = astFromString(content);
		}

		// Cache the AST for future use
		variables.astCache[arguments.path] = ast;

		// DEBUG: write the ast to a debug file if environment variable set
		writeDebugAstIfEnabled(arguments.path, ast);

		return ast;
	}

	/**
	 * Writes AST to debug file if LCOV_DEBUG_AST environment variable is set.
	 * @path File path (used for debug filename)
	 * @ast AST object to write
	 */
	private void function writeDebugAstIfEnabled(required string path, required any ast) {
		var debugAstOutput = structKeyExists(server.system.environment, "LCOV_DEBUG_AST")
			&& server.system.environment.LCOV_DEBUG_AST == "true";

		if (debugAstOutput) {
			var astDebugDir = getTempDirectory() & "lcov-ast-debug/";
			if (!directoryExists(astDebugDir)) {
				directoryCreate(astDebugDir);
			}
			var fileName = listLast(arguments.path, "\/");
			var astDebugPath = astDebugDir & fileName & ".ast.json";
			variables.logger.debug("Writing AST debug file: " & astDebugPath);
			fileWrite(astDebugPath, serializeJSON(arguments.ast, false, "utf-8"));
		}
	}

	/**
	 * Returns the AST cache for inspection or batch operations.
	 * @return struct AST cache
	 */
	public struct function getAstCache() {
		return variables.astCache;
	}

}
