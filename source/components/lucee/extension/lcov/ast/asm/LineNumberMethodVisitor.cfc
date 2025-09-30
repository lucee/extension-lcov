/**
 * ASM MethodVisitor to collect line numbers from method bytecode.
 * Called for each method in the class to extract line number information.
 *
 * NOTE: Using implementsJava instead of extends - see LineNumberCollector.cfc for explanation.
 * Must have identical javasettings to LineNumberCollector to share classloader.
 */
component implementsJava="org.objectweb.asm.MethodVisitor" javasettings='{
	"maven": [
		{
			"groupId": "org.ow2.asm",
			"artifactId": "asm",
			"version": "9.5"
		}
	]
}' {

	variables.lineNumbers = {};
	variables.ASM_API = 524288; // ASM9

	public function init(required numeric api, required struct lineNumbersStruct) {
		variables.lineNumbers = arguments.lineNumbersStruct;
		return this;
	}

	public void function visitLineNumber(required numeric line, required any start) {
		// Record this line number
		variables.lineNumbers[arguments.line] = true;
	}

	// Required MethodVisitor methods
	public function visitParameter(name, access) {}
	public function visitAnnotationDefault() {}
	public function visitAnnotation(descriptor, visible) {}
	public function visitTypeAnnotation(typeRef, typePath, descriptor, visible) {}
	public function visitAnnotableParameterCount(parameterCount, visible) {}
	public function visitParameterAnnotation(parameter, descriptor, visible) {}
	public function visitAttribute(attribute) {}
	public function visitCode() {}
	public function visitFrame(type, numLocal, local, numStack, stack) {}
	public function visitInsn(opcode) {}
	public function visitIntInsn(opcode, operand) {}
	public function visitVarInsn(opcode, varIndex) {}
	public function visitTypeInsn(opcode, type) {}
	public function visitFieldInsn(opcode, owner, name, descriptor) {}
	public function visitMethodInsn(opcode, owner, name, descriptor, isInterface) {}
	public function visitInvokeDynamicInsn(name, descriptor, bootstrapMethodHandle, bootstrapMethodArguments) {}
	public function visitJumpInsn(opcode, label) {}
	public function visitLabel(label) {}
	public function visitLdcInsn(value) {}
	public function visitIincInsn(varIndex, increment) {}
	public function visitTableSwitchInsn(min, max, dflt, labels) {}
	public function visitLookupSwitchInsn(dflt, keys, labels) {}
	public function visitMultiANewArrayInsn(descriptor, numDimensions) {}
	public function visitInsnAnnotation(typeRef, typePath, descriptor, visible) {}
	public function visitTryCatchBlock(start, end, handler, type) {}
	public function visitTryCatchAnnotation(typeRef, typePath, descriptor, visible) {}
	public function visitLocalVariable(name, descriptor, signature, start, end, index) {}
	public function visitLocalVariableAnnotation(typeRef, typePath, start, end, index, descriptor, visible) {}
	public function visitMaxs(maxStack, maxLocals) {}
	public function visitEnd() {}
}