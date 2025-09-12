@echo off
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
set LUCEE_LOGGING_FORCE_APPENDER=console
set LUCEE_LOGGING_FORCE_LEVEL=info
set LUCEE_BUILD_ENV=
set testLabels=lcov
set testFilter=%testFilter%
set testServices=mysql
set HTTPBIN_PORT=-1
set HTTPBIN_SERVER=noexist

rem Run tests using script-runner (use proper ant syntax)
ant -buildfile="d:\work\script-runner\build.xml" -Dwebroot="d:\work\lucee7\test" -Dexecute="bootstrap-tests.cfm"  -DextensionDir="D:\work\lucee-extensions\extension-lcov\target" -DluceeVersionQuery="7/all/light" -DtestAdditional="d:\work\lucee-extensions\extension-lcov\tests" -DtestLabels="%testLabels%" -DtestFilter="%testFilter%" 

echo.
echo Test run complete!
pause