/**
 * HTML Assets component for generating CSS and other web assets
 * for the LCOV code coverage HTML reports
 */
component output="false" {

	/**
	 * Gets the common CSS link tag for coverage reports
	 * @return string HTML link tag
	 */
	public string function getCommonCss() {
		return '<link rel="stylesheet" href="assets/css/coverage-report.css">';
	}

	/**
	 * Gets the dark mode toggle JavaScript script tag
	 * @return string HTML script tag
	 */
	public string function getDarkModeScript() {
		return '<script src="assets/js/dark-mode.js"></script>';
	}

	/**
	 * Gets the table sorting JavaScript script tag
	 * @return string HTML script tag
	 */
	public string function getTableSortScript() {
		return '<script src="assets/js/table-sort.js"></script>';
	}

	/**
	 * Copies CSS and JS assets to the output directory
	 * @param outputDir The directory where HTML reports are written
	 */
	public void function copyAssets(required string outputDir) {
		var assetsOutputDir = arguments.outputDir & "/assets";

		// Create assets directory structure
		if (!directoryExists(assetsOutputDir)) {
			directoryCreate(assetsOutputDir);
		}
		if (!directoryExists(assetsOutputDir & "/css")) {
			directoryCreate(assetsOutputDir & "/css");
		}
		if (!directoryExists(assetsOutputDir & "/js")) {
			directoryCreate(assetsOutputDir & "/js");
		}

		// Copy CSS file
		var cssSource = getAssetPath("css/coverage-report.css");
		var cssTarget = assetsOutputDir & "/css/coverage-report.css";
		fileCopy(cssSource, cssTarget);

		// Copy JS files
		var jsFiles = ["dark-mode.js", "table-sort.js"];
		for (var jsFile in jsFiles) {
			var jsSource = getAssetPath("js/" & jsFile);
			var jsTarget = assetsOutputDir & "/js/" & jsFile;
			fileCopy(jsSource, jsTarget);
		}
	}

	/**
	 * Gets the absolute path to an asset file
	 * @param relativePath The relative path from the assets directory
	 * @return string The absolute path to the asset file
	 */
	private string function getAssetPath(string relativePath) {
		// Get the directory where this component is located
		var componentPath = getCurrentTemplatePath();
		var componentDir = getDirectoryFromPath(componentPath);

		// Assets are now in the same directory as this component
		var assetsPath = componentDir & "assets" & server.separator.file & arguments.relativePath;

		return assetsPath;
	}
}