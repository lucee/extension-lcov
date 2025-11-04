/**
 * ASM ClassVisitor to collect line numbers from bytecode.
 * This visitor walks through all methods and collects line numbers from their LineNumberTable.
 *
 * NOTE: Using implementsJava instead of extends because:
 * 1. The extends="java:..." syntax fails when the class isn't available during component parsing
 * 2. implementsJava allows us to implement the interface/class contract without inheritance
 * 3. We can then cast this component to the Java type when needed
 */
component implementsJava="org.objectweb.asm.ClassVisitor" javasettings='{
	"maven": [
		{
			"groupId": "org.ow2.asm",
			"artifactId": "asm",
			"version": "9.5"
		}
	]
}' {

	import org.objectweb.asm.MethodVisitor;

	variables.lineNumbers = {};
	variables.ASM_API = 524288; // ASM9

	/**
	 * Initialize the collector with a line numbers struct
	 * @lineNumbersStruct Struct to populate with line numbers (passed by reference)
	 * @return This instance
	 */
	public function init(required struct lineNumbersStruct) {
		variables.lineNumbers = arguments.lineNumbersStruct;
		return this;
	}

	/**
	 * Visit a method in the class file
	 * @return MethodVisitor for this method
	 */
	public function visitMethod(access, name, descriptor, signature, exceptions) {
		// Return a MethodVisitor to visit this method
		return new LineNumberMethodVisitor(variables.ASM_API, variables.lineNumbers);
	}

	// Required ClassVisitor methods
	public function visit(version, access, name, signature, superName, interfaces) {}
	public function visitSource(source, debug) {}
	public function visitModule(name, access, version) {}
	public function visitNestHost(nestHost) {}
	public function visitOuterClass(owner, name, descriptor) {}
	public function visitAnnotation(descriptor, visible) {}
	public function visitTypeAnnotation(typeRef, typePath, descriptor, visible) {}
	public function visitAttribute(attribute) {}
	public function visitNestMember(nestMember) {}
	public function visitPermittedSubclass(permittedSubclass) {}
	public function visitInnerClass(name, outerName, innerName, access) {}
	public function visitRecordComponent(name, descriptor, signature) {}
	public function visitField(access, name, descriptor, signature, value) {}
	public function visitEnd() {}
}