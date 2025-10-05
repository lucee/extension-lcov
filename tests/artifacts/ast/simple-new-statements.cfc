component {

	public function init() {
		variables.logger = new Logger();
		variables.factory = new ComponentFactory();
		return this;
	}

	public function createStuff() {
		var obj1 = new SomeComponent();
		var obj2 = new AnotherComponent();
		return obj1;
	}

}
