/**
 * JfrEvent - Java Flight Recorder event wrapper for LCOV performance tracking
 *
 * This component provides a simple interface to emit JFR events for profiling
 * LCOV coverage analysis performance with minimal overhead.
 *
 * Events will be captured when script-runner is run with -DflightRecording=true
 *
 * Usage:
 *   var jfr = new JfrEvent();
 *   var event = jfr.begin("CallTreeExtract");
 *   event.file = filePath;
 *   // ... do work ...
 *   event.cacheHit = true;
 *   jfr.commit(event);
 */
component {

	variables.enabled = false;
	variables.activeEvents = {};
	variables.useNativeJfr = false;
	variables.eventTypes = {};
	variables.FlightRecorder = nullValue();
	variables.EventFactory = nullValue();

	/**
	 * Initialize JFR support - only attempts if JFR is actually recording
	 */
	public function init() {
		// Check if jdk.jfr module is exported (required for custom events)
		var runtimeMXBean = createObject("java", "java.lang.management.ManagementFactory").getRuntimeMXBean();
		var inputArgs = runtimeMXBean.getInputArguments();
		var hasJfrExport = false;

		systemOutput("=== JFR Debug: JVM Arguments ===", true);
		for (var i = 0; i < inputArgs.size(); i++) {
			var arg = inputArgs.get(i);
			systemOutput("  " & arg, true);
			if (findNoCase("add-exports", arg) && findNoCase("jdk.jfr", arg)) {
				hasJfrExport = true;
			}
		}
		systemOutput("=== End JVM Arguments ===", true);

		if (!hasJfrExport) {
			// jdk.jfr module not exported - custom events won't work
			variables.enabled = false;
			variables.useNativeJfr = false;
			systemOutput("JFR: jdk.jfr module not exported - custom events disabled (need --add-exports jdk.jfr/jdk.jfr=ALL-UNNAMED)", true);
			return this;
		}

		// Check if JFR is available and recording
		// Use system classloader to access jdk.jfr classes (not Lucee's dynamic classloader)
		var systemClassLoader = createObject("java", "java.lang.ClassLoader").getSystemClassLoader();
		var FlightRecorderClass = systemClassLoader.loadClass("jdk.jfr.FlightRecorder");
		variables.FlightRecorder = FlightRecorderClass;
		var getFlightRecorderMethod = FlightRecorderClass.getMethod("getFlightRecorder", javaCast("null", ""));
		var flightRecorder = getFlightRecorderMethod.invoke(javaCast("null", ""), javaCast("null", ""));

		// Check if any recording is active
		var getRecordingsMethod = FlightRecorderClass.getMethod( "getRecordings", javaCast( "null", "" ) );
		var recordings = getRecordingsMethod.invoke( flightRecorder, javaCast( "null", "" ) );
		var hasActiveRecording = false;
		for (var i = 0; i < recordings.size(); i++) {
			var recording = recordings.get( i );
			var getStateMethod = recording.getClass().getMethod( "getState", javaCast( "null", "" ) );
			var state = getStateMethod.invoke( recording, javaCast( "null", "" ) );
			if (state.toString() == "RUNNING") {
				hasActiveRecording = true;
				break;
			}
		}

		if (!hasActiveRecording) {
			// JFR not recording - don't bother initializing
			variables.enabled = false;
			variables.useNativeJfr = false;
			return this;
		}

		variables.enabled = true;
		variables.useNativeJfr = false;  // type="java" can't access jdk.jfr due to classloader restrictions
		systemOutput( "JFR: Recording active, timing tracking enabled (custom JFR events not supported)", true );

		return this;
	}

	/**
	 * Begin a JFR event - returns an event object that can be populated with attributes
	 * @eventName Event name (e.g., "CallTreeExtract", "ExlFileParse")
	 * @return Event struct with begin time
	 */
	public struct function begin(required string eventName) {
		var event = {
			name: arguments.eventName,
			startTime: getTickCount(),
			startNano: createObject("java", "java.lang.System").nanoTime()
		};

		if (variables.enabled) {
			// Store event for commit
			var eventId = createUUID();
			variables.activeEvents[eventId] = event;
			event.eventId = eventId;
		}

		return event;
	}

	/**
	 * Commit a JFR event (ends it and emits to JFR)
	 * @event Event struct returned from begin()
	 */
	public void function commit(required struct event) {
		if (!variables.enabled) {
			return;
		}

		arguments.event.endTime = getTickCount();
		arguments.event.endNano = java:System::nanoTime();
		arguments.event.durationMs = arguments.event.endTime - arguments.event.startTime;
		arguments.event.durationNano = arguments.event.endNano - arguments.event.startNano;

		// Emit custom JFR event if native JFR is available
		if (variables.useNativeJfr) {
			try {
				emitJfrEvent(arguments.event);
			} catch (any e) {
				// Silently fail if JFR emission fails
			}
		}

		// Clean up
		if (structKeyExists(arguments.event, "eventId")) {
			structDelete(variables.activeEvents, arguments.event.eventId);
		}
	}

	/**
	 * Emit a custom JFR event - placeholder for future implementation
	 * @event Event struct with attributes
	 */
	private void function emitJfrEvent( required struct event ) {
		// Custom JFR events not currently supported
		// Would require compiled Java class in extension
	}

	/**
	 * Emit a simple instant event (no duration)
	 * @eventName Event name
	 * @attributes Attributes to attach
	 */
	public void function emit(required string eventName, struct attributes = {}) {
		if (!variables.enabled) {
			return;
		}

		var event = begin(arguments.eventName);
		for (var key in arguments.attributes) {
			event[key] = arguments.attributes[key];
		}
		commit(event);
	}

	/**
	 * Check if JFR is enabled
	 */
	public boolean function isEnabled() {
		return variables.enabled;
	}
}
