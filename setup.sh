#!/bin/bash
echo "=== Word-Level Transcript Engine Setup ==="
echo ""

# Create virtual environment
echo "[1/3] Creating Python virtual environment..."
python3 -m venv venv || { echo "ERROR: Failed to create venv. Make sure Python 3 is installed."; exit 1; }

# Activate and install requirements
echo "[2/3] Installing Python dependencies..."
source venv/bin/activate
pip install -r requirements.txt || { echo "ERROR: Failed to install dependencies."; exit 1; }

# Copy .env template
echo "[3/3] Setting up environment config..."
if [ ! -f .env ]; then
    cp .env.template .env
    echo "Created .env file - please edit it with your GROQ_API_KEY and FFMPEG_PATH"
else
    echo ".env already exists, skipping."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit .env with your GROQ_API_KEY and FFMPEG_PATH"
echo "  2. Run: source venv/bin/activate && python -m uvicorn backend.main:app --reload"
echo "  3. Open web_ui/index.html in your browser"
echo ""
