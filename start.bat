@echo off
REM ============================================
REM APEX Housing — Full Stack Startup
REM Run this from the project root
REM ============================================

set PROJECT_DIR=%~dp0
set BACKEND_DIR=%PROJECT_DIR%backend
set USER_APP_DIR=%PROJECT_DIR%frontend\user-app
set ADMIN_APP_DIR=%PROJECT_DIR%frontend\apex_admin

echo ============================================
echo   APEX Housing — Starting All Services
echo ============================================
echo.

REM --- 1. Start Redis ---
echo [1/4] Starting Redis...
set REDIS_DIR=%TEMP%\redis5
start /B "" "%REDIS_DIR%\redis-server.exe" "%REDIS_DIR%\redis-custom.conf"
timeout /t 2 /nobreak >nul
"%REDIS_DIR%\redis-cli.exe" -p 6380 ping >nul 2>&1
if %errorlevel%==0 (
    echo       Redis OK on port 6380
) else (
    echo       Redis not found — starting without it (rate limiting disabled)
)

REM --- 2. Start Backend ---
echo [2/4] Starting Backend (FastAPI on port 8099)...
start "APEX Backend" cmd /c "cd /d "%BACKEND_DIR%" && python run_app.py"
timeout /t 3 /nobreak >nul
echo       Backend starting at http://localhost:8099
echo       API docs at http://localhost:8099/docs

REM --- 3. Start User App ---
echo [3/4] Starting User App (Flutter)...
start "APEX User App" cmd /c "cd /d "%USER_APP_DIR%" && flutter run -d chrome --web-port=5173"
echo       User app starting at http://localhost:5173

REM --- 4. Start Admin App ---
echo [4/4] Starting Admin App (Flutter)...
start "APEX Admin App" cmd /c "cd /d "%ADMIN_APP_DIR%" && flutter run -d chrome --web-port=5174"
echo       Admin app starting at http://localhost:5174

echo.
echo ============================================
echo   All services starting:
echo ============================================
echo   Backend:    http://localhost:8099
echo   API Docs:   http://localhost:8099/docs
echo   User App:   http://localhost:5173
echo   Admin App:  http://localhost:5174
echo   Redis:      localhost:6380
echo ============================================
echo.
echo Close the service windows to stop them.
