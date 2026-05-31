# Word-Level Transcript Engine

Extracts word-level timestamps and power words from audio/video using AI transcription + forced alignment.

---

## Quick Start (One-Click Setup)

Clone the repo, then double-click the launcher — everything else is automatic:

```bash
git clone https://github.com/samm329-ui/CaptionGen.git
cd CaptionGen
```

| Platform | Action |
|---|---|
| **Windows** | Double-click `start.bat` |
| **Linux / macOS** | Run `./start.sh` or `bash start.sh` |

The launcher automatically:
1. Checks Python is installed
2. Creates a virtual environment
3. Installs all Python dependencies
4. Sets up the `.env` configuration file
5. Finds or installs FFmpeg
6. Starts the server and opens http://localhost:8000 in your browser

On first run, you'll be prompted to add your `GROQ_API_KEY` in the `.env` file. Get a free key at https://console.groq.com/

---

## Architecture

Two-pass pipeline — transcription and alignment are decoupled:

1. **Pass 1 (Transcription)** — Groq Cloud API running `whisper-large-v3` produces raw text per audio chunk. No timestamps returned.
2. **Pass 2 (Alignment)** — WhisperX forced alignment using local `wav2vec2` models matches each word to its precise position in the audio waveform.

---

## Pipeline Flow

```
Video file
  │
  ▼
[1] FFmpeg audio extraction → .wav
  │
  ▼
[2] Audio quality analysis (librosa)
    - SNR estimation (harmonic/percussive source separation)
    - Speech rate (onset detection)
    - → adaptive thresholds for downstream scoring
  │
  ▼
[3] Overlapping audio chunking (pydub)
    - Normal mode:  30s chunks, 2s overlap
    - Strict mode:  15s chunks, 3s overlap (noisy audio, SNR < 10dB)
    - Fade in/out applied to each chunk
  │
  ▼
[4] Per-chunk processing (sequential):
    │
    ├─ [4a] Groq Whisper API (whisper-large-v3) → raw text
    ├─ [4b] Language detection (Unicode block analysis) → en/hi/bn/hinglish
    ├─ [4c] Filler word removal (um, uh, er, Hindi/Bengali fillers)
    ├─ [4d] LLM refinement (Groq Llama 3.3 70B) → grammar, spelling, transliteration
    ├─ [4e] Hallucination guard (word-count diff, repeated n-grams)
    ├─ [4f] Quality scoring:
    │        - LM pre-check (spellcheck) → if score > 0.9, use directly
    │        - Dual score = 0.60 × semantic_similarity + 0.40 × keyword_retention
    └─ [4g] Confidence gate (language-aware thresholds)
  │
  ▼
[5] Chunk merge (order-safe, overlap deduplication)
  │
  ▼
[6] Sentence splitting (punctuation + max 10 words)
    - Each sentence inherits proportional time from parent chunk
  │
  ▼
[7] WhisperX forced alignment (wav2vec2)
    - English: WAV2VEC2_ASR_BASE_960H
    - Hindi/Bengali: theainerd/Wav2Vec2-large-xlsr-hindi
    - → per-word timestamps: {word, start, end, score}
  │
  ▼
[8] Drift clamping (0.02s min gap between consecutive words)
  │
  ▼
[9] Alignment validation (avg score >= 0.65, low-score ratio <= 30%)
  │
  ▼
[10] Output → SRT + VTT (word-level: each word is a separate subtitle entry)
```

---

## Word-Level Output Format

Each aligned segment contains a `words` array:

```json
{
  "segments": [
    {
      "text": "Hello world how are you",
      "start": 0.0,
      "end": 2.5,
      "words": [
        {"word": "Hello", "start": 0.0, "end": 0.4, "score": 0.92},
        {"word": "world", "start": 0.45, "end": 0.85, "score": 0.88},
        {"word": "how",  "start": 1.0, "end": 1.3, "score": 0.91},
        {"word": "are",  "start": 1.35, "end": 1.55, "score": 0.87},
        {"word": "you",  "start": 1.6, "end": 2.0, "score": 0.93}
      ]
    }
  ]
}
```

SRT output (word-level):
```
1
00:00:00,000 --> 00:00:00,400
Hello

2
00:00:00,450 --> 00:00:00,850
world

3
00:00:01,000 --> 00:00:01,300
how
```

---

## Models and APIs

| Component | Model/API | Source |
|---|---|---|
| Transcription | `whisper-large-v3` | Groq Cloud API |
| LLM Refinement | `llama-3.3-70b-versatile` | Groq Cloud API |
| Alignment (English) | `WAV2VEC2_ASR_BASE_960H` | WhisperX (local) |
| Alignment (Hindi/Bengali) | `theainerd/Wav2Vec2-large-xlsr-hindi` | WhisperX (local) |
| Semantic Embeddings | `paraphrase-multilingual-MiniLM-L12-v2` | sentence-transformers (local) |
| Audio Analysis | librosa | local |
| Audio Extraction | FFmpeg | system binary |

Only one API key required: `GROQ_API_KEY` (used for both Whisper and Llama).

---

## Supported Languages

| Language | Transcription | Alignment Model |
|---|---|---|
| English | Groq Whisper | WAV2VEC2_ASR_BASE_960H |
| Hindi (Devanagari) | Groq Whisper | Wav2Vec2-large-xlsr-hindi |
| Bengali | Groq Whisper | Wav2Vec2-large-xlsr-hindi |
| Hinglish (Hindi in Latin script) | Groq Whisper + LLM transliteration | Wav2Vec2-large-xlsr-hindi |

---

## Fresh PC Setup (From Zero)

This section covers every dependency needed on a completely fresh machine. Follow in order.

### What You Need

| Dependency | Required | Why |
|---|---|---|
| **Python 3.10+** | Yes | Runtime for the entire backend + AI pipeline |
| **pip** | Yes | Python package installer (comes with Python) |
| **FFmpeg** | Yes | Audio extraction from video, subtitle burn-in export |
| **Git** | Optional | Only if you want version control / cloning from GitHub |
| **Groq API Key** | Yes | Cloud API for Whisper transcription + Llama LLM |
| **Node.js** | **No** | Frontend uses CDN React/Tailwind/Babel — no build step |

### Windows

#### 1. Install Python 3.10+

Download from: https://www.python.org/downloads/

**IMPORTANT:** During installation, check the box that says **"Add Python to PATH"**.

Verify after install:
```bash
python --version
# Should show: Python 3.10.x or higher

pip --version
# Should show: pip 23.x or higher
```

If `python` is not found, try `py` instead, or add Python to PATH manually:
```
Control Panel → System → Advanced System Settings → Environment Variables
→ Path → Edit → New → C:\Users\<you>\AppData\Local\Programs\Python\Python310\
```

#### 2. Install FFmpeg

Download from: https://github.com/BtbN/FFmpeg-Builds/releases

1. Download `ffmpeg-master-latest-win64-gpl.zip`
2. Extract to `C:\ffmpeg\`
3. The executable will be at `C:\ffmpeg\bin\ffmpeg.exe`

Verify:
```bash
C:\ffmpeg\bin\ffmpeg.exe -version
```

You do NOT need to add FFmpeg to system PATH — the application reads the path from `.env`.

#### 3. Install Git (Optional)

Download from: https://git-scm.com/download/win

Use default settings during installation. Verify:
```bash
git --version
```

#### 4. Get a Groq API Key

1. Go to https://console.groq.com/
2. Create a free account
3. Go to API Keys → Create New Key
4. Copy the key (starts with `gsk_`)

---

### Linux (Ubuntu/Debian)

#### 1. Install Python 3.10+

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

python3 --version
pip3 --version
```

#### 2. Install FFmpeg

```bash
sudo apt install -y ffmpeg

ffmpeg -version
```

#### 3. Install Git (Optional)

```bash
sudo apt install -y git

git --version
```

#### 4. Get a Groq API Key

Same as Windows — https://console.groq.com/

---

### macOS

#### 1. Install Python 3.10+

```bash
# Install Homebrew first (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python@3.12

python3 --version
pip3 --version
```

#### 2. Install FFmpeg

```bash
brew install ffmpeg

ffmpeg -version
```

#### 3. Install Git (Optional)

```bash
# Git comes with Xcode Command Line Tools
xcode-select --install

git --version
```

#### 4. Get a Groq API Key

Same as Windows/Linux — https://console.groq.com/

---

## Install and Run

### Option A: One-Click Setup (Recommended)

```bash
git clone https://github.com/samm329-ui/CaptionGen.git
cd CaptionGen
```

- **Windows**: Double-click `start.bat`
- **Linux / macOS**: Run `./start.sh`

The launcher handles everything: venv creation, dependency installation, `.env` setup, FFmpeg detection, and server startup.

### Option B: Manual Setup

If you prefer manual control:

```bash
git clone https://github.com/samm329-ui/CaptionGen.git
cd CaptionGen
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.template .env
```

Edit `.env` and fill in:
```
GROQ_API_KEY=gsk_your_actual_key_here
FFMPEG_PATH=C:\ffmpeg\bin\ffmpeg.exe
```

- **Windows**: `FFMPEG_PATH=C:\ffmpeg\bin\ffmpeg.exe`
- **Linux**: `FFMPEG_PATH=/usr/bin/ffmpeg`
- **macOS**: `FFMPEG_PATH=/opt/homebrew/bin/ffmpeg` (Apple Silicon) or `/usr/local/bin/ffmpeg` (Intel)

Start the server:
```bash
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Open http://localhost:8000 in your browser.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `python` not found | Use `python3` instead, or add Python to PATH |
| `pip` not found | Run `python -m pip install -r requirements.txt` |
| `ffmpeg` not found | Check `.env` FFMPEG_PATH points to the correct location |
| `GROQ_API_KEY` warning | Make sure `.env` has your real key, not the placeholder |
| First run is slow | Model download (~2-3 GB). Only happens once. |
| Torch/CUDA errors | The engine auto-detects GPU. Falls back to CPU if no CUDA. Works on CPU, just slower. |
| Port 8000 in use | Change `--port 8000` to another port like `--port 8080` |

---

## Project Structure

```
word-level-transcript-engine/
├── caption_engine/              # Core AI pipeline (24 Python modules)
│   ├── main.py                  # Pipeline orchestrator (run_pipeline)
│   ├── config.py                # All tuning constants and thresholds
│   ├── transcriber.py           # Groq Whisper API call
│   ├── audio.py                 # FFmpeg extraction + pydub chunking
│   ├── aligner.py               # WhisperX forced alignment
│   ├── alignment_models.py      # wav2vec2 model loader with caching
│   ├── alignment_validator.py   # Alignment quality validation
│   ├── llm_judge.py             # Llama 3.3 70B transcript refinement
│   ├── dual_scorer.py           # Semantic similarity + keyword scoring
│   ├── quality_estimator.py     # SNR, speech rate analysis
│   ├── chunk_merger.py          # Overlap deduplication
│   ├── sentence_splitter.py     # Caption-sized sentence splitting
│   ├── renderer.py              # SRT + VTT output generation
│   ├── hallucination_guard.py   # Whisper hallucination detection
│   ├── drift_clamp.py           # Word timestamp gap enforcement
│   ├── lang_detector.py         # Unicode-based language detection
│   ├── preprocessor.py          # Filler word removal
│   ├── confidence.py            # Language-aware confidence gating
│   ├── normalizer.py            # Text normalization for scoring
│   ├── lm_check.py              # Spellcheck-based pre-check
│   ├── cache.py                 # Hash-based content cache
│   ├── retry.py                 # Exponential backoff decorator
│   └── logger.py                # JSONL structured logging
│
├── backend/                     # FastAPI server
│   ├── main.py                  # App setup, CORS, static files
│   ├── database.py              # SQLite schema (aiosqlite)
│   ├── pipeline_runner.py       # Async-to-sync bridge for pipeline
│   ├── models.py                # Pydantic response models
│   ├── progress.py              # WebSocket connection manager
│   └── api/
│       ├── jobs.py              # REST endpoints + WebSocket progress
│       └── health.py            # Health check
│
├── web_ui/                      # React 18 frontend (no build step, all CDN)
│   ├── index.html               # SPA shell (React CDN + Tailwind CDN)
│   ├── app.jsx                  # Main app with view routing
│   ├── api.js                   # API client
│   └── components/
│       ├── UploadCard.jsx        # Video upload + language selector
│       ├── ProgressCard.jsx      # Real-time progress via WebSocket
│       ├── ResultCard.jsx        # SRT/VTT display + export
│       ├── Dashboard.jsx         # Project dashboard
│       ├── HistoryList.jsx       # Job history
│       └── LoadingScreen.jsx     # Loading splash
│
├── data/                        # Runtime (created automatically)
│   ├── uploads/                 # Uploaded video files
│   ├── logs/                    # JSONL pipeline logs
│   └── database.sqlite          # Job database (auto-created)
│
├── start.bat                    # Windows one-click launcher
├── start.sh                     # Linux/macOS one-click launcher
├── requirements.txt             # Python dependencies
├── .env.template                # Environment variable template
├── .gitignore
└── README.md
```

---

## Key Design Decisions

- **Transcription is text-only** — Groq Whisper returns plain text, no timestamps. Word-level timing comes entirely from WhisperX alignment.
- **Two-pass architecture** — transcription and alignment are separate steps. Cloud API for transcription, local models for alignment.
- **Overlapping chunks** — prevents word loss at chunk boundaries. Overlap deduplication runs after merge.
- **LLM refinement** — Llama 3.3 70B corrects grammar/spelling and handles Hinglish transliteration. Temperature 0.1 for deterministic output.
- **Quality gating** — every chunk is scored and must pass a confidence threshold. Low-quality chunks fall back to raw transcription or are discarded.
- **Hallucination guard** — Whisper sometimes hallucinates repeated phrases. Detected via word-count drift and n-gram repetition checks.
- **All paths are relative** — uses `__file__`-based path resolution. The folder works from any location on any machine.
- **No Node.js required** — frontend loads React, Tailwind, and Babel directly from CDN. No build step, no npm, no node_modules.
