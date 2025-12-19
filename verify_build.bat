@echo off
echo ========================================
echo ThyScan Build Verification Script
echo ========================================
echo.

echo [1/5] Cleaning previous builds...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed
    exit /b 1
)
echo SUCCESS: Build cleaned
echo.

echo [2/5] Getting dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed
    exit /b 1
)
echo SUCCESS: Dependencies downloaded
echo.

echo [3/5] Running static analysis...
call flutter analyze
if %errorlevel% neq 0 (
    echo WARNING: Some analysis issues found, but continuing...
)
echo.

echo [4/5] Building debug APK...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo ERROR: Build failed!
    echo.
    echo Common fixes:
    echo - Delete android/.gradle folder
    echo - Delete android/.kotlin folder
    echo - Check android/app/google-services.json exists
    echo - Run: gradlew clean in android folder
    exit /b 1
)
echo SUCCESS: Debug APK built successfully!
echo.

echo [5/5] Checking APK location...
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo SUCCESS: APK found at build\app\outputs\flutter-apk\app-debug.apk
    for %%I in ("build\app\outputs\flutter-apk\app-debug.apk") do echo APK size: %%~zI bytes
) else (
    echo ERROR: APK not found!
    exit /b 1
)
echo.

echo ========================================
echo BUILD VERIFICATION COMPLETE!
echo ========================================
echo.
echo Next steps:
echo 1. Test APK: flutter install
echo 2. Run on device: flutter run
echo 3. Build release: flutter build appbundle --release
echo.
pause
