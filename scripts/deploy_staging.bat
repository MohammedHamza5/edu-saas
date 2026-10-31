@echo off
echo ==============================================
echo Deploying to Firebase Staging (hosting:test)...
echo ==============================================
set NODE_OPTIONS=--dns-result-order=ipv4first

:retry1
echo Attempt 1...
call firebase deploy --only hosting:test
if %ERRORLEVEL% equ 0 goto success

echo Attempt 1 failed. Waiting 5 seconds before retry 2...
timeout /t 5 /nobreak >nul
echo Attempt 2...
call firebase deploy --only hosting:test
if %ERRORLEVEL% equ 0 goto success

echo Attempt 2 failed. Waiting 8 seconds before retry 3...
timeout /t 8 /nobreak >nul
echo Attempt 3...
call firebase deploy --only hosting:test
if %ERRORLEVEL% equ 0 goto success

echo All attempts failed.
exit /b 1

:success
echo ==============================================
echo Staging Deployment Succeeded!
echo ==============================================
exit /b 0
