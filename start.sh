#!/bin/bash
# FYAP Pro - One-Click Launcher (Linux/macOS)
set -e

echo ""
echo "============================================================"
echo "    FYAP Pro - Word-Level Transcript Engine"
echo "    One-Click Setup & Launch"
echo "============================================================"
echo ""

# ============================================================
#  STEP 1: Check Python
# ============================================================
echo "[1/6] Checking Python..."

PYTHON_CMD=""
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
else
    echo ""
    echo "ERROR: Python 3 is not installed."
    echo ""
    echo "Install Python 3.10+:"
    echo "  Ubuntu/Debian:  sudo apt install python3 python3-venv python3-pip"
    echo "  macOS:          brew install python3"
    echo "  Fedora:         sudo dnf install python3"
    echo ""
    exit 1
fi

PYVER=$($PYTHON_CMD --version 2>&1)
echo "  Found $PYVER"

# ============================================================
#  STEP 2: Create Virtual Environment
# ============================================================
echo ""
echo "[2/6] Setting up virtual environment..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "venv/bin/activate" ]; then
    echo "  Creating new virtual environment..."
    $PYTHON_CMD -m venv venv
    echo "  Virtual environment created."
else
    echo "  Virtual environment already exists."
fi

# Activate venv
source venv/bin/activate

# ============================================================
#  STEP 3: Install Python Dependencies
# ============================================================
echo ""
echo "[3/6] Installing Python dependencies..."

if [ -d "venv/lib" ] && find venv/lib -path "*/fastapi/__init__.py" -print -quit 2>/dev/null | grep -q .; then
    echo "  Dependencies already installed, checking for updates..."
    pip install -r requirements.txt -q --disable-pip-version-check 2>/dev/null || true
else
    echo "  Installing packages (this may take a few minutes on first run)..."
    pip install -r requirements.txt --disable-pip-version-check
fi
echo "  Dependencies ready."

# ============================================================
#  STEP 4: Setup .env Configuration
# ============================================================
echo ""
echo "[4/6] Setting up configuration..."

if [ ! -f ".env" ]; then
    cp .env.template .env
    echo "  Created .env from template."
    echo "  NOTE: You will need to add your GROQ_API_KEY in the .env file."
    echo "  Get your key at: https://console.groq.com/"
else
    echo "  .env already exists."
fi

# ============================================================
#  STEP 5: Find or Install FFmpeg
# ============================================================
echo ""
echo "[5/6] Checking FFmpeg..."

FFMPEG_FOUND=""

# Check 1: Is ffmpeg in PATH?
if command -v ffmpeg &>/dev/null; then
    FFMPEG_FOUND="$(command -v ffmpeg)"
fi

# Check 2: Read FFMPEG_PATH from .env
if [ -z "$FFMPEG_FOUND" ] && [ -f ".env" ]; then
    ENV_FFMPEG=$(grep -i "^FFMPEG_PATH=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    if [ -n "$ENV_FFMPEG" ] && [ -f "$ENV_FFMPEG" ]; then
        FFMPEG_FOUND="$ENV_FFMPEG"
    fi
fi

# Check 3: Common locations
if [ -z "$FFMPEG_FOUND" ]; then
    for path in /usr/bin/ffmpeg /usr/local/bin/ffmpeg /opt/homebrew/bin/ffmpeg; do
        if [ -f "$path" ]; then
            FFMPEG_FOUND="$path"
            break
        fi
    done
fi

# FFmpeg not found - try to install
if [ -z "$FFMPEG_FOUND" ]; then
    echo "  FFmpeg not found. Attempting to install..."

    # Detect OS and package manager
    if command -v apt-get &>/dev/null; then
        echo "  Installing via apt..."
        sudo apt-get update -qq && sudo apt-get install -y -qq ffmpeg
    elif command -v brew &>/dev/null; then
        echo "  Installing via Homebrew..."
        brew install ffmpeg
    elif command -v dnf &>/dev/null; then
        echo "  Installing via dnf..."
        sudo dnf install -y ffmpeg
    elif command -v pacman &>/dev/null; then
        echo "  Installing via pacman..."
        sudo pacman -S --noconfirm ffmpeg
    else
        echo ""
        echo "  WARNING: Could not auto-install FFmpeg."
        echo "  Install manually: https://ffmpeg.org/download.html"
        echo ""
    fi

    # Re-check after install attempt
    if command -v ffmpeg &>/dev/null; then
        FFMPEG_FOUND="$(command -v ffmpeg)"
    fi
fi

if [ -n "$FFMPEG_FOUND" ]; then
    echo "  FFmpeg found: $FFMPEG_FOUND"
    # Update .env with the found FFmpeg path
    if [ -f ".env" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^FFMPEG_PATH=.*|FFMPEG_PATH=$FFMPEG_FOUND|" .env
        else
            sed -i "s|^FFMPEG_PATH=.*|FFMPEG_PATH=$FFMPEG_FOUND|" .env
        fi
    fi
    # Add to PATH for this session
    FFMPEG_DIR="$(dirname "$FFMPEG_FOUND")"
    export PATH="$FFMPEG_DIR:$PATH"
else
    echo ""
    echo "  WARNING: FFmpeg could not be installed automatically."
    echo "  The server will start but transcription may fail."
    echo "  Install FFmpeg manually and set FFMPEG_PATH in .env"
    echo ""
fi

# ============================================================
#  STEP 6: Start the Server
# ============================================================
echo ""
echo "[6/6] Starting FYAP Pro server..."
echo ""
echo "============================================================"
echo "  Server starting at: http://localhost:8000"
echo "  Press Ctrl+C to stop the server"
echo "============================================================"
echo ""

# Open browser in background
if command -v xdg-open &>/dev/null; then
    (sleep 3 && xdg-open "http://localhost:8000") &
elif command -v open &>/dev/null; then
    (sleep 3 && open "http://localhost:8000") &
fi

# Start the FastAPI server
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
