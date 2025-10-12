component {

	public void function sleepFor5Ms() {
		// Sleep for 5 milliseconds - predictable timing
		sleep(5);
	}

	public void function sleepFor10Ms() {
		// Sleep for 10 milliseconds - predictable timing
		sleep(10);
	}

	public void function callsAnotherMethod() {
		// This method calls another method
		// The child time here should be ~10ms (from sleepFor10Ms)
		// The total time should be ~10ms + overhead
		sleepFor10Ms();
	}

}
