@echo off
cd /d "%~dp0"

:top
cls
echo.
echo  ============================================================
echo     FYAP Pro - Word-Level Transcript Engine
echo     One-Click Setup ^& Launch
echo  ============================================================
echo.

REM --- STEP 1: Check Python ---
echo [1/6] Checking Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Python is not installed or not in PATH.
    echo.
    echo  Download Python 3.10+ from: https://www.python.org/downloads/
    echo  IMPORTANT: Check "Add Python to PATH" during install!
    echo.
    echo  Press any key to exit...
    pause >nul
    exit /b
)
python --version
echo.

REM --- STEP 2: Create Virtual Environment ---
echo [2/6] Setting up virtual environment...
if not exist "venv\Scripts\activate.bat" (
    echo  Creating new virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo  ERROR: Failed to create virtual environment.
        echo  Press any key to exit...
        pause >nul
        exit /b
    )
    echo  Virtual environment created.
) else (
    echo  Virtual environment already exists.
)
echo.

REM --- STEP 3: Activate and Install Dependencies ---
echo [3/6] Activating virtual environment...
call venv\Scripts\activate.bat
echo  Virtual environment activated.
echo.

echo [3/6] Installing Python dependencies...
echo  (This may take a few minutes on first run)
pip install -r requirements.txt --disable-pip-version-check
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Failed to install dependencies.
    echo  Press any key to exit...
    pause >nul
    exit /b
)
echo.
echo  Dependencies installed successfully.
echo.

REM --- STEP 4: Setup .env ---
echo [4/6] Setting up configuration...
if not exist ".env" (
    copy .env.template .env >nul
    echo  Created .env from template.
    echo.
    echo  IMPORTANT: You need to add your GROQ_API_KEY in the .env file.
    echo  Get your key at: https://console.groq.com/
    echo.
    echo  Opening .env file for you to edit...
    notepad .env
    echo.
    echo  Please save and close Notepad, then press any key to continue...
    pause >nul
) else (
    echo  .env already exists.
)
echo.

REM --- STEP 5: Check FFmpeg ---
echo [5/6] Checking FFmpeg...
set "FFMPEG_EXE="
where ffmpeg >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%a in ('where ffmpeg') do set "FFMPEG_EXE=%%a"
    echo  Found FFmpeg: %FFMPEG_EXE%
    goto :ffmpeg_ok
)
echo  FFmpeg not found in PATH.
echo.
echo  Please install FFmpeg:
echo    1. Download from: https://www.gyan.dev/ffmpeg/builds/
echo    2. Extract to C:\ffmpeg
echo    3. Add C:\ffmpeg\bin to your system PATH
echo.
echo  The server will start but transcription may fail without FFmpeg.
echo.
:ffmpeg_ok
echo.

REM --- STEP 6: Start Server ---
echo [6/6] Starting FYAP Pro server...
echo.
echo  ============================================================
echo   Server will start at: http://localhost:8000
echo   Press Ctrl+C to stop the server
echo  ============================================================
echo.

REM Open browser after a short delay
start "" /min cmd /c "timeout /t 3 >nul & start http://localhost:8000"

REM Start the FastAPI server
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000

echo.
echo  Server stopped.
echo  Press any key to exit...
pause >nul
