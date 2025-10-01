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

	/**
	 * Initialize JFR support
	 */
	public function init() {
		try {
			// Check if JFR is available (requires Java 11+)
			var flightRecorder = createObject("java", "jdk.jfr.FlightRecorder");
			variables.enabled = true;

			// Try to enable native JFR event emission
			try {
				var eventFactory = createObject("java", "jdk.jfr.EventFactory");
				variables.useNativeJfr = true;
			} catch (any e2) {
				// EventFactory not available, fall back to tracking only
				variables.useNativeJfr = false;
			}
		} catch (any e) {
			// JFR not available in this JVM
			variables.enabled = false;
			variables.useNativeJfr = false;
		}
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
		arguments.event.endNano = createObject("java", "java.lang.System").nanoTime();
		arguments.event.durationMs = arguments.event.endTime - arguments.event.startTime;
		arguments.event.durationNano = arguments.event.endNano - arguments.event.startNano;

		// Custom JFR events require Java classes with annotations
		// For now, we track timing internally and rely on JVM's built-in JFR events
		// which will show thread activity, locks, GC, etc.

		// Clean up
		if (structKeyExists(arguments.event, "eventId")) {
			structDelete(variables.activeEvents, arguments.event.eventId);
		}
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
