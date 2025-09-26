component {
	/**
	 * Safely contracts a file path , falling back to original path if contraction fails
	 */
	public string function safeContractPath(required string filePath) {
		try {
			var contractedPath = contractPath(arguments.filePath);
			return (isNull(contractedPath) || contractedPath == "null" || contractedPath contains "null") 
				? arguments.filePath : contractedPath;
		} catch (any e) {
			return arguments.filePath;
		}
	}
}
