cls
SET JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-11.0.25.9-hotspot
call mvn package
set testLabels=lcov
set testFilter=generatehtml
set LUCEE_LOGGING_FORCE_APPENDER=console
set LUCEE_LOGGING_FORCE_LEVEL=info
set LUCEE_BUILD_ENV=

ant -buildfile="d:\work\script-runner\build.xml" -Dwebroot="d:\work\lucee7\test" -Dexecute="bootstrap-tests.cfm" -DextensionDir="D:\work\lucee-extensions\extension-lcov\target" -DluceeVersionQuery="7/all/jar" -DtestAdditional="d:\work\lucee-extensions\extension-lcov\tests"