/**
 * Logger - Centralized logging with timestamps and log levels
 *
 * Provides consistent logging across LCOV extension with:
 * - Timestamp prefixes for performance analysis
 * - Log levels: none (silent), trace, debug, info
 * - Event tracking for duration measurement
 * - Future JFR integration hooks
 *
 * Usage:
 *   var logger = new Logger(level="info");  // Default is "none" (silent)
 *   logger.info("Starting process...");
 *   logger.debug("Processing chunk 5");
 *
 *   var event = logger.beginEvent("ChunkProcessing");
 *   event.chunkIdx = 5;
 *   // ... do work ...
 *   logger.commitEvent(event);
 */
component accessors="true" {

	property name="level" type="string" default="none";
	property name="jfrEnabled" type="boolean" default="false";
	property name="logMemory" type="boolean" default="true";

	variables.levels = {
		"none": 0,
		"info": 1,
		"debug": 2,
		"trace": 3
	};

	/**
	 * Initialize logger with specified log level
	 * @level Log level: "none" (silent), "trace", "debug", or "info" (default: "none")
	 * @jfrEnabled Enable JFR event emission (default: false)
	 * @logMemory Include heap memory usage in log output (default: false)
	 */
	public function init(string level="none", boolean jfrEnabled=false, boolean logMemory=true) {
		variables.level = arguments.level;
		variables.jfrEnabled = arguments.jfrEnabled;
		variables.logMemory = arguments.logMemory;
		return this;
	}

	/**
	 * Get current log level
	 * @return Current log level string
	 */
	public string function getLevel() {
		return variables.level;
	}

	/**
	 * Log INFO level message - shown if level is info, debug, or trace
	 * @message Message to log
	 */
	public void function info(required string message) {
		if (shouldLog("info")) {
			output("INFO", arguments.message);
		}
	}

	/**
	 * Log DEBUG level message - shown if level is debug or trace
	 * @message Message to log
	 */
	public void function debug(required string message) {
		if (shouldLog("debug")) {
			output("DEBUG", arguments.message);
		}
	}

	/**
	 * Log TRACE level message - shown only if level is trace
	 * @message Message to log
	 */
	public void function trace(required string message) {
		if (shouldLog("trace")) {
			output("TRACE", arguments.message);
		}
	}

	/**
	 * Begin tracking an event
	 * @eventName Name of the event (e.g., "ChunkProcessing", "Aggregation")
	 * @return Event struct that can be populated with attributes
	 */
	public struct function beginEvent(required string eventName) {
		return {
			name: arguments.eventName,
			startTime: getTickCount(),
			startNano: createObject("java", "java.lang.System").nanoTime()
		};
	}

	/**
	 * Commit an event (logs duration and emits to JFR if enabled)
	 * @event Event struct returned from beginEvent()
	 * @minThresholdMs Minimum duration in milliseconds to log (-1 = don't log, 0 = always log, >0 = only log if duration >= threshold)
	 * @logLevel Log level to use: "trace" (default), "debug", or "info"
	 */
	public void function commitEvent(required struct event, numeric minThresholdMs=0, string logLevel="trace") {
		arguments.event["endTime"] = getTickCount();
		arguments.event["endNano"] = createObject("java", "java.lang.System").nanoTime();
		arguments.event["durationMs"] = arguments.event["endTime"] - arguments.event["startTime"];
		arguments.event["durationNano"] = arguments.event["endNano"] - arguments.event["startNano"];

		// Check if we should skip logging based on threshold
		if (arguments.minThresholdMs == -1 || (arguments.minThresholdMs > 0 && arguments.event["durationMs"] < arguments.minThresholdMs)) {
			return;
		}

		// Log event at specified level with all attributes
		if (shouldLog(arguments.logLevel)) {
			var msg = "Event: " & arguments.event["name"] & " completed in " & numberFormat(arguments.event["durationMs"]) & "ms";

			// Add any custom attributes (skip internal tracking fields)
			var skipFields = ["name", "startTime", "endTime", "startNano", "endNano", "durationMs", "durationNano"];
			for (var key in arguments.event) {
				if (!arrayFindNoCase(skipFields, key)) {
					msg &= ", " & key & "=" & arguments.event[key];
				}
			}

			output(uCase(arguments.logLevel), msg);
		}

		// Future: emit to JFR if enabled
		if (variables.jfrEnabled) {
			// emitToJfr(arguments.event);
		}
	}

	/**
	 * Internal: Format and output log message with timestamp, optional memory usage, and level
	 */
	private void function output(required string level, required string message) {
		var timestamp = timeFormat(now(), "HH:nn:ss.SSS");
		var paddedLevel = lJustify(arguments.level, 5);
		var memoryInfo = variables.logMemory ? "[" & getHeapUsedMB() & "MB] " : "";
		systemOutput("[" & timestamp & "] [" & paddedLevel & "] " & memoryInfo & arguments.message, true);
	}

	/**
	 * Internal: Get current heap usage in MB
	 */
	private numeric function getHeapUsedMB() {
		var runtime = createObject("java", "java.lang.Runtime").getRuntime();
		var usedBytes = runtime.totalMemory() - runtime.freeMemory();
		return round(usedBytes / 1024 / 1024);
	}

	/**
	 * Internal: Check if a message at the requested level should be logged
	 */
	private boolean function shouldLog(required string requestedLevel) {
		return variables.levels[arguments.requestedLevel] <= variables.levels[variables.level];
	}
}
