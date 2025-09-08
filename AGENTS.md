### Lucee LCOV extension

- targets Lucee 7
- reads the output from [lucee.runtime.engine.ResourceExecutionLog](https://github.com/lucee/Lucee/blob/7.0/core/src/main/java/lucee/runtime/engine/ResourceExecutionLog.java) 
- produces an LCOV file, json data files and html reports about line coverage
- this vs code extension supports the LCOV files produced https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters

### Tests

- tests go in the /tests folder
- use testbox for testings
- all tests should extend  org.lucee.cfml.test.LuceeTestCase
- all tests should use the label "lcov"
- as a general approach to testing, always leave any generated artifacts in place for review afterwards, simply clean them in the beforeAll steps
- tests can be run using script-runner, read the d:\work\script-runner\README.md
- refer to https://docs.lucee.org/guides/working-with-source/build-from-source.html#build-performance-tips for how the lucee test runner works
- don't repeat logic in tests, use a private method
- use matchers https://testbox.ortusbooks.com/digging-deeper/expectations/matchers
- avoid try catch, if a test fails, let error, the lucee exception is more meaningful
- if you are catching an error to add useful info the the error, throw don't systemOutput and use e.stacktrace instead of e.message and the cause attribute
- avoid long tests, split them into smaller tests if they get too large
- when running tests and an error occurs, always show me the error
- admin password is stored in `request.SERVERADMINPASSWORD`
- only check for the existance of public methods, as in the public API, not private methods

to run tests, use `/test.bat`

```
ant -buildfile="d:\work\script-runner\build.xml"  -Dwebroot="d:\work\lucee7\test" -Dexecute="/bootstrap-tests.cfm" -DextensionDir="d:\work\lucee-extensions\extension-lcov\target" -DluceeVersionQuery="7/all/light" -DtestAdditional="d:\work\lucee-extensions\extension-lcov\tests"
```
