rem echo off
echo Running LCOV Extension Tests

echo.
echo Building extension first...
call mvn package

if errorlevel 1 (
    echo Extension build failed!
    pause
    exit /b 1
)

echo.
echo Extension built successfully. Running tests...

set testLabels=lcov

if "%1"=="" (
    set testFilter=
) else (
    set testFilter=%1
)
set LUCEE_LOGGING_FORCE_APPENDER=
set LUCEE_LOGGING_FORCE_LEVEL=info
set LUCEE_BUILD_ENV=
set testLabels=lcov
set testFilter=%testFilter%
set testServices=none
set testExcludeDefault=true
set HTTPBIN_PORT=
set HTTPBIN_SERVER=noexist
SET LUCEE_CASCADING_WRITE_TO_VARIABLES_LOG=deloy
SET LUCEE_JAR=
REM D:\work\lucee7\loader\target\lucee-7.0.1.7-SNAPSHOT.jar

if exist tests\generated-artifacts rmdir /s /q tests\generated-artifacts

echo -----------------------------------------------------

rem Run tests using script-runner (use proper ant syntax)
ant -buildfile="d:\work\script-runner\build.xml" -Dwebroot="d:\work\lucee7\test" -Dexecute="bootstrap-tests.cfm" -DtestHideJavaStack="true" -DextensionDir="D:\work\lucee-extensions\extension-lcov\target" -DluceeVersionQuery="7.0/snapshot/jar" -DtestAdditional="d:\work\lucee-extensions\extension-lcov\tests" -DluceeJar="%LUCEE_JAR%"

echo.
echo Test run complete!
pause