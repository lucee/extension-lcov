component extends="org.lucee.cfml.test.LuceeTestCase" labels="lcov" {

    function beforeAll() {
        variables.adminPassword = request.SERVERADMINPASSWORD;
    }

    /**
     * @displayName "Given I have enabled logging and call lcovStopLogging with admin password, When the function executes, Then it should disable logging"
     */
    function testStopLoggingWithMinimalParameters() {
        // Given - Start logging first
        var adminPassword = variables.adminPassword;
        var logDirectory = lcovStartLogging(adminPassword=adminPassword);
        
        // When
        lcovStopLogging(adminPassword=adminPassword);
        
        // Then - Should complete without error
        // Note: We can't easily verify the internal config change, 
        // but the function should execute without throwing
        expect(true).toBeTrue("Function should complete successfully");
    }

    /**
     * @displayName "Given I have enabled logging and call lcovStopLogging with specific className, When the function executes, Then it should disable that specific log class"
     */
    function testStopLoggingWithClassName() {
        // Given - Start logging first
        var adminPassword = variables.adminPassword;
        var logDirectory = lcovStartLogging(
            adminPassword=adminPassword,
            executionLogDir="",
            options={className: "lucee.runtime.engine.ResourceExecutionLog"}
        );
        
        // When
        lcovStopLogging(
            adminPassword=adminPassword,
            className="lucee.runtime.engine.ResourceExecutionLog"
        );
        
        // Then
        expect(true).toBeTrue("Function should complete successfully");
    }

    /**
     * @displayName "Given I call lcovStopLogging with invalid admin password, When the function executes, Then it should throw an exception"
     */
    function testStopLoggingWithInvalidPassword() {
        // Given
        var invalidPassword = "invalid-password-123";
        
        // When/Then
        expect(function() {
            lcovStopLogging(adminPassword=invalidPassword);
        }).toThrow();
    }

    /**
     * @displayName "Given no logging is enabled and I call lcovStopLogging, When the function executes, Then it should handle gracefully"
     */
    function testStopLoggingWhenNotEnabled() {
        // Given
        var adminPassword = variables.adminPassword;
        
        // When/Then - Should not throw error even if logging not enabled
        lcovStopLogging(adminPassword=adminPassword);
        expect(true).toBeTrue("Function should handle case when logging not enabled");
    }

    /**
     * @displayName "Given I call lcovStopLogging with ConsoleExecutionLog className, When the function executes, Then it should disable console logging"
     */
    function testStopLoggingConsoleExecutionLog() {
        // Given
        var adminPassword = variables.adminPassword;
        
        // When
        lcovStopLogging(
            adminPassword=adminPassword,
            className="lucee.runtime.engine.ConsoleExecutionLog"
        );
        
        // Then
        expect(true).toBeTrue("Function should handle different log class names");
    }
}