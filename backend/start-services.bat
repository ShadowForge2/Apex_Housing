@echo off
REM ============================================
REM APEX Housing — Start Redis + Celery Worker + Beat
REM Run this from the backend directory
REM ============================================

set BACKEND_DIR=%~dp0
set REDIS_DIR=%TEMP%\redis5

REM --- Start Redis ---
echo Starting Redis on port 6380...
start /B "" "%REDIS_DIR%\redis-server.exe" "%REDIS_DIR%\redis-custom.conf"
timeout /t 2 /nobreak >nul

REM Verify Redis
"%REDIS_DIR%\redis-cli.exe" -p 6380 ping
if errorlevel 1 (
    echo ERROR: Redis failed to start!
    exit /b 1
)
echo Redis is running on port 6380.

REM --- Start Celery Worker ---
echo Starting Celery worker...
start "Celery Worker" cmd /c "cd /d "%BACKEND_DIR%" && python -m celery -A app.tasks.celery_app:celery_app worker --loglevel=info --pool=solo --concurrency=1"

REM --- Start Celery Beat ---
echo Starting Celery beat scheduler...
start "Celery Beat" cmd /c "cd /d "%BACKEND_DIR%" && python -m celery -A app.tasks.celery_app:celery_app beat --loglevel=info"

echo.
echo All services started:
echo   Redis:       localhost:6380
echo   Celery Work: window "Celery Worker"
echo   Celery Beat: window "Celery Beat"
echo.
echo To stop: close the windows or run stop-services.bat
