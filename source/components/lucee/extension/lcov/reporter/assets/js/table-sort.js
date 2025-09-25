// Table sorting functionality for coverage reports
function sortTable(th, sortDefault) {
	var tr = th.parentElement;
	var table = tr.parentElement.parentElement; // table;
	var tbodys = table.getElementsByTagName("tbody");
	var theads = table.getElementsByTagName("thead");
	var rowspans = (table.dataset.rowspan !== "false");

	if (!th.dataset.type)
		th.dataset.type = sortDefault; // otherwise text
	// Clear direction from all other headers in this table
	var allHeaders = tr.querySelectorAll('th');
	for (var i = 0; i < allHeaders.length; i++) {
		if (allHeaders[i] !== th) {
			delete allHeaders[i].dataset.dir;
		}
	}

	if (!th.dataset.dir) {
		th.dataset.dir = "asc";
	} else {
		if (th.dataset.dir == "asc")
			th.dataset.dir = "desc";
		else
			th.dataset.dir = "asc";
	}
	for (var h = 0; h < tr.children.length; h++) {
		var cell = tr.children[h].style;
		if (h === th.cellIndex) {
			cell.fontWeight = 700;
			cell.fontStyle = (th.dataset.dir == "desc") ? "normal" : "italic";
		} else {
			cell.fontWeight = 300;
			cell.fontStyle = "normal";
		}
	}
	var sortGroup = false;
	var localeCompare = "test".localeCompare ? true : false;
	var numberParser = new Intl.NumberFormat('en-US');
	var data = [];

	for (var b = 0; b < tbodys.length; b++) {
		var tbody = tbodys[b];
		for (var r = 0; r < tbody.children.length; r++) {
			var row = tbody.children[r];
			var group = false;
			if (row.classList.length > 0) {
				// check for class sort-group
				group = row.classList.contains("sort-group");
			}
			// this is to handle secondary rows with rowspans, but this stops two column tables from sorting
			if (group) {
				data[data.length - 1][1].push(row);
			} else {
				switch (row.childElementCount) {
					case 0:
					case 1:
						continue;
					case 2:
						if (!rowspans)
							break;
						if (data.length > 1)
							data[data.length - 1][1].push(row);
						continue;
					default:
						break;
				}
				var cell = row.children[th.cellIndex];
				var val = cell.innerText;
				if (!localeCompare) {
					switch (th.dataset.type) {
						case "text":
							val = val.toLowerCase();
							break;
						case "numeric":
						case "number":
							switch (val) {
								case "":
								case "-":
									val = -1;
									break;
								default:
									val = Number(val);
									break;
							}
							break;
					}
				} else {
					if (cell.dataset.value)
						val = cell.dataset.value;
					// Handle formatted numbers with commas and units (e.g., "1,234 μs" or "56.7%")
					var cleanVal = val.replace(/[^\d.,%-]/g, ''); // Keep digits, commas, periods, %, -
					cleanVal = cleanVal.replace(/,/g, ''); // Remove commas
					cleanVal = cleanVal.replace(/%$/, ''); // Remove trailing %
					var tmpNum = Number(cleanVal);
					if (!isNaN(tmpNum)) {
						val = String(tmpNum);
					}
				}
				var _row = row;
				if (r === 0 &&
					theads.length > 1 &&
					tbody.previousElementSibling.nodeName === "THEAD" &&
					tbody.previousElementSibling.children.length) {
					data.push([val, [tbody.previousElementSibling, row], tbody]);
					sortGroup = true;
				} else {
					data.push([val, [row]]);
				}

			}
		}
	}

	switch (th.dataset.type) {
		case "text":
			data = data.sort(function (a, b) {
				if (localeCompare) {
					return a[0].localeCompare(b[0], "en", { numeric: true, ignorePunctuation: true });
				} else {
					if (a[0] < b[0])
						return -1;
					if (a[0] > b[0])
						return 1;
					return 0;
				}
			});
			break;
		case "numeric":
		case "number":
			data = data.sort(function (a, b) {
				return a[0] - b[0];
			});
	}

	if (th.dataset.dir === "desc")
		data.reverse();
	if (!sortGroup) {
		for (r = 0; r < data.length; r++) {
			for (var rr = 0; rr < data[r][1].length; rr++)
				tbody.appendChild(data[r][1][rr]);
		}
	} else {
		for (r = 0; r < data.length; r++) {

			if (data[r].length === 3) {
				var _rows = data[r];
				table.appendChild(_rows[1][0]); // thead
				table.appendChild(_rows[2]); // tbody
				var _tbody = _rows[2];
				for (var rr = 1; rr < _rows[1].length; rr++)
					_tbody.appendChild(_rows[1][rr]); // tr

			} else {
				for (var rr = 0; rr < data[r][1].length; rr++)
					table.appendChild(data[r][1][rr]);
			}
		}
	}
}

// Initialize table sorting when DOM is loaded
function initTableSorting() {
	// Find all sortable tables
	var tables = document.querySelectorAll('.sortable-table');
	tables.forEach(function(table) {
		var headers = table.querySelectorAll('thead th');
		headers.forEach(function(th, index) {
			// Make headers clickable and add appropriate data types
			th.style.cursor = 'pointer';
			th.style.userSelect = 'none';

			// Set data type from semantic markup
			th.dataset.type = th.dataset.sortType || 'text';

			// Add click handler
			th.addEventListener('click', function() {
				sortTable(th, th.dataset.type);
			});

			// Add visual indicator for sortable columns
			th.title = 'Click to sort by ' + th.textContent;
		});
	});
}

// Initialize when DOM is loaded
if (document.readyState === 'loading') {
	document.addEventListener('DOMContentLoaded', initTableSorting);
} else {
	initTableSorting();
}