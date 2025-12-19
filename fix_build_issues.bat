@echo off
echo ========================================
echo ThyScan Build Issue Fixer
echo ========================================
echo.
echo This script will:
echo - Clean all build caches
echo - Delete corrupted Kotlin incremental cache
echo - Reset Gradle daemon
echo - Prepare for fresh build
echo.
pause

echo [1/6] Stopping Gradle daemon...
cd android
call gradlew --stop
cd ..
echo SUCCESS: Gradle daemon stopped
echo.

echo [2/6] Deleting Kotlin incremental cache...
if exist "android\.kotlin" (
    rmdir /s /q "android\.kotlin"
    echo SUCCESS: Kotlin cache deleted
) else (
    echo INFO: No Kotlin cache found
)
echo.

echo [3/6] Deleting Gradle cache...
if exist "android\.gradle" (
    rmdir /s /q "android\.gradle"
    echo SUCCESS: Gradle cache deleted
) else (
    echo INFO: No Gradle cache found
)
echo.

echo [4/6] Deleting build directory...
if exist "build" (
    rmdir /s /q "build"
    echo SUCCESS: Build directory deleted
) else (
    echo INFO: No build directory found
)
echo.

echo [5/6] Running Flutter clean...
call flutter clean
echo SUCCESS: Flutter clean completed
echo.

echo [6/6] Getting fresh dependencies...
call flutter pub get
echo SUCCESS: Dependencies downloaded
echo.

echo ========================================
echo BUILD CACHES CLEANED!
echo ========================================
echo.
echo You can now run:
echo   flutter build apk
echo   OR
echo   flutter run
echo.
echo If build still fails, check:
echo - android/app/google-services.json exists
echo - Internet connection active
echo - Sufficient disk space (5GB+ free)
echo.
pause
