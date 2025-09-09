/**
 * HTML Assets component for generating CSS and other web assets
 * for the LCOV code coverage HTML reports
 */
component output="false" {

	/**
	 * Gets the common CSS styles for coverage reports by reading from external CSS file
	 * @return string CSS styles
	 */
	public string function getCommonCss() {
		var cssPath = getAssetPath("css/coverage-report.css");
		return fileRead(cssPath);
	}

	/**
	 * Gets the dark mode toggle JavaScript by reading from external JS file
	 * @return string JavaScript code for dark mode toggle
	 */
	public string function getDarkModeScript() {
		var jsPath = getAssetPath("js/dark-mode.js");
		var jsContent = fileRead(jsPath);
		return "<script>" & jsContent & "</script>";
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