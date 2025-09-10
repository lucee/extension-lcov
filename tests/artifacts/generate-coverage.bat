@echo off
cls
echo Generating .exl files for LCOV extension test artifacts

rem Set Java version
SET JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.5.11-hotspot

rem Enable code coverage logging
set EXELOG=codeCoverage

echo.
echo Running coverage for coverage-simple-sequential.cfm...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/coverage-simple-sequential.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Running coverage for conditional.cfm...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/conditional.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Running coverage for loops.cfm...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/loops.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Running coverage for functions-example.cfm...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/functions-example.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Running coverage for exception.cfm...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/exception.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Running coverage for complete test runner...
call ant -buildfile="d:\work\script-runner" -DluceeVersion="7.0.0.370-SNAPSHOT" -Dwebroot="D:\work\lucee-extensions\extension-lcov\tests\artifacts" -Dexecute="/kitchen-sink-example.cfm" -DluaceeVersionQuery="7/all/jar" -Ddebugger="false" -DFlightRecording="false" -DpostCleanup="false"

echo.
echo Coverage generation complete! Check for .exl files in the script-runner logs directory.
pause