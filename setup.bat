@echo off
echo === Word-Level Transcript Engine Setup ===
echo.

REM Create virtual environment
echo [1/3] Creating Python virtual environment...
python -m venv venv
if errorlevel 1 (
    echo ERROR: Failed to create venv. Make sure Python is installed.
    pause
    exit /b 1
)

REM Activate and install requirements
echo [2/3] Installing Python dependencies...
call venv\Scripts\activate.bat
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)

REM Copy .env template
echo [3/3] Setting up environment config...
if not exist .env (
    copy .env.template .env
    echo Created .env file - please edit it with your GROQ_API_KEY and FFMPEG_PATH
) else (
    echo .env already exists, skipping.
)

echo.
echo === Setup Complete ===
echo.
echo Next steps:
echo   1. Edit .env with your GROQ_API_KEY and FFMPEG_PATH
echo   2. Run: venv\Scripts\activate ^&^& python -m uvicorn backend.main:app --reload
echo   3. Open web_ui/index.html in your browser
echo.
pause
