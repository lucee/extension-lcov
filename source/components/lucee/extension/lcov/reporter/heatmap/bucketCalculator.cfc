/**
 * Bucket calculation component for heatmap data distribution
 * Handles percentile-based bucket assignment algorithms
 */
component output="false" {

	/**
	 * Calculates ranges based on data distribution for variable bucket count
	 * @param values Array of numeric values
	 * @param bucketCount Number of buckets to create
	 * @return array of threshold values for each bucket level
	 */
	public array function calculateRanges(array values, numeric bucketCount) {
		if (arrayLen(arguments.values) == 0) {
			return [];
		}
		
		// Sort values to calculate percentiles
		arraySort(arguments.values, "numeric");
		var len = arrayLen(arguments.values);
		var thresholds = [];
		
		// Calculate percentile thresholds for each bucket
		for (var i = 1; i <= arguments.bucketCount; i++) {
			var percentile = i / arguments.bucketCount;
			var index = max(1, int(len * percentile));
			arrayAppend(thresholds, arguments.values[index]);
		}
		
		return thresholds;
	}
	
	/**
	 * Determines the numeric level for a given value based on threshold array
	 * @param value The value to classify
	 * @param thresholds Array of threshold values for each level
	 * @return numeric Level: 1, 2, 3, etc.
	 */
	public numeric function getValueLevel(numeric value, array thresholds) {
		for (var i = 1; i <= arrayLen(arguments.thresholds); i++) {
			if (arguments.value <= arguments.thresholds[i]) {
				return i;
			}
		}
		// If value exceeds all thresholds, return the highest level
		return arrayLen(arguments.thresholds);
	}

	/**
	 * Calculates optimal bucket counts based on unique values in the data
	 * @param countValues Array of execution count values
	 * @param timeValues Array of execution time values
	 * @param maxBuckets Maximum number of buckets allowed
	 * @return struct containing countBucketCount and timeBucketCount
	 */
	public struct function calculateOptimalBucketCounts(array countValues, array timeValues, numeric maxBuckets) {
		// Calculate unique values for each data type
		var uniqueCountValues = [];
		for (var val in arguments.countValues) {
			if (arrayFind(uniqueCountValues, val) == 0) {
				arrayAppend(uniqueCountValues, val);
			}
		}
		
		var uniqueTimeValues = [];
		for (var val in arguments.timeValues) {
			if (arrayFind(uniqueTimeValues, val) == 0) {
				arrayAppend(uniqueTimeValues, val);
			}
		}
		
		return {
			"countBucketCount": min(arguments.maxBuckets, max(1, arrayLen(uniqueCountValues))),
			"timeBucketCount": min(arguments.maxBuckets, max(1, arrayLen(uniqueTimeValues)))
		};
	}

	/**
	 * Calculates bucket assignments for a list of execution times
	 * Used primarily for testing bucket assignment logic
	 * @param times Array of execution times (zero values are excluded)
	 * @param bucketCount Number of buckets to create
	 * @return struct mapping each time to its bucket number (0-based)
	 */
	public struct function calculateBuckets(array times, numeric bucketCount) {
		var result = {};
		
		// Filter out zero values
		var nonZeroTimes = [];
		for (var time in arguments.times) {
			if (time > 0) {
				arrayAppend(nonZeroTimes, time);
			}
		}
		
		// Handle empty data
		if (arrayLen(nonZeroTimes) == 0) {
			return result;
		}
		
		// Calculate bucket ranges using existing method
		var ranges = calculateRanges(nonZeroTimes, arguments.bucketCount);
		
		// Assign each time to a bucket (convert to 0-based for test compatibility)
		for (var time in nonZeroTimes) {
			var level = getValueLevel(time, ranges);
			result[time] = level - 1; // Convert to 0-based indexing
		}
		
		return result;
	}
}