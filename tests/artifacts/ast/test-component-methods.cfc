component {
	function init() {
		return this;
	}

	function test() {
		init();  // This should not be marked as built-in
		var obj = new MyComponent();
		obj.someMethod();  // This should not be marked as built-in
	}
}