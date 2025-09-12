component {
	/**
	 * Generates the legend HTML for coverage reports.
	 */
	public string function generateLegendHtml() {
		return '<div class="coverage-legend">'
			& '<h4 class="legend-title">Legend</h4>'
			& '<table class="code-table legend-table">'
				& '<tr class="executed">'
					& '<td class="legend-description">Executed lines - Code that was run during testing</td>'
				& '</tr>'
				& '<tr class="not-executed">'
					& '<td class="legend-description">Not executed - Executable code that was not run</td>'
				& '</tr>'
				& '<tr class="non-executable">'
					& '<td class="legend-description">Non-executable - Comments, empty lines (not counted in coverage)</td>'
				& '</tr>'
			& '</table>'
		& '</div>';
	}
}
