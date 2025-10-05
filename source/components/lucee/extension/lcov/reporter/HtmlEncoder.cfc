/**
* CFC responsible for HTML encoding with fallback support
*/
component {

	/**
	* Constructor/init function
	*/
	public function init() {
		// Check if ESAPI extension is available during initialization
		variables.hasEsapi = extensionExists("37C61C0A-5D7E-4256-8572639BE0CF5838");
		return this;
	}

	/**
	* HTML encodes a string with fallback to core CFML function
	* @text String to encode
	* @return HTML-encoded string
	*/
	public string function htmlEncode(required string text) {
		if (variables.hasEsapi) {
			// Use the newer encodeForHtml function if ESAPI is available
			return encodeForHtml(arguments.text);
		} else {
			// Fall back to core CFML function
			return htmlEditFormat(arguments.text);
		}
	}

	/**
	* HTML attribute encodes a string with fallback to core CFML function
	* @text String to encode
	* @return HTML attribute-encoded string
	*/
	public string function htmlAttributeEncode(required string text) {
		if (variables.hasEsapi) {
			// Use the newer encodeForHtmlAttribute function if ESAPI is available
			return encodeForHtmlAttribute(arguments.text);
		} else {
			// Fall back to core CFML function (htmlEditFormat works for attributes too)
			return htmlEditFormat(arguments.text);
		}
	}

	// these will be ignored for the BIF, but allows compiling without ESAPI installed
	private string function encodeForHtml(required string text) {
		throw( type="NotImplemented", message="This placeholder should never be called - use the BIF instead" );
	}
	private string function encodeForHtmlAttribute(required string text) {
		throw( type="NotImplemented", message="This placeholder should never be called - use the BIF instead" );
	}
}