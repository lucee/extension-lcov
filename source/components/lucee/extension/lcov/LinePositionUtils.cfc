component {

	/**
	 * Hot path optimized binary search to find line number from character position
	 * @charPos Character position to find
	 * @lineMapping Array of character positions for each line start
	 * @mappingLen Length of lineMapping array (pre-calculated for performance)
	 * @minLine Starting line hint for sequential processing (default 1)
	 * @return Line number, or 0 if position is invalid/not found
	 */
	public static numeric function getLineFromCharacterPosition(charPos, lineMapping, mappingLen, minLine = 1) {
		var c = arguments.charPos;
		var m = arguments.lineMapping;
		var len = arguments.mappingLen;
		var low = arguments.minLine;
		var high = len;

		while (low <= high) {
			var mid = int((low + high) / 2);

			if (mid == len) {
				return m[mid] <= c ? mid : mid - 1;
			} else if (m[mid] <= c && c < m[mid + 1]) {
				return mid;
			} else if (m[mid] > c) {
				high = mid - 1;
			} else {
				low = mid + 1;
			}
		}

		return 0; // Not found - signals invalid position to caller
	}

}