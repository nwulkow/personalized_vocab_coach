#!/bin/bash

# Vokabeltrainer Startup Script
# This script starts both the FastAPI backend and Vue.js frontend

echo "🚀 Starting Vokabeltrainer Application..."
echo ""

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to cleanup background processes on exit
cleanup() {
    echo ""
    echo "🛑 Stopping servers..."
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
    fi
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
    fi
    echo "✅ Servers stopped"
    exit 0
}

# Set up trap to catch Ctrl+C
trap cleanup SIGINT SIGTERM

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please create one first:"
    echo "   python3 -m venv venv"
    exit 1
fi

# Activate virtual environment
echo -e "${BLUE}📦 Activating Python virtual environment...${NC}"
source venv/bin/activate

# Make Node.js available in non-interactive shells (e.g. when launched from VS Code/Finder)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Prefer a real Node binary from common macOS locations, then fall back to nvm or Homebrew.
NODE_BIN=""
NPM_BIN=""

if [ -x "/opt/homebrew/bin/node" ] && [ -x "/opt/homebrew/bin/npm" ]; then
    NODE_BIN="/opt/homebrew/bin/node"
    NPM_BIN="/opt/homebrew/bin/npm"
elif [ -x "/usr/local/bin/node" ] && [ -x "/usr/local/bin/npm" ]; then
    NODE_BIN="/usr/local/bin/node"
    NPM_BIN="/usr/local/bin/npm"
else
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        # shellcheck disable=SC1090
        source "$HOME/.nvm/nvm.sh"
        NVM_NODE_BIN="$(command -v node 2>/dev/null)"
        NVM_NPM_BIN="$(command -v npm 2>/dev/null)"
        if [ -n "$NVM_NODE_BIN" ] && [ -n "$NVM_NPM_BIN" ]; then
            NODE_BIN="$NVM_NODE_BIN"
            NPM_BIN="$NVM_NPM_BIN"
        fi
    elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        source "/opt/homebrew/opt/nvm/nvm.sh"
        NVM_NODE_BIN="$(command -v node 2>/dev/null)"
        NVM_NPM_BIN="$(command -v npm 2>/dev/null)"
        if [ -n "$NVM_NODE_BIN" ] && [ -n "$NVM_NPM_BIN" ]; then
            NODE_BIN="$NVM_NODE_BIN"
            NPM_BIN="$NVM_NPM_BIN"
        fi
    elif command -v brew &> /dev/null; then
        eval "$(brew shellenv)"
        if [ -x "$(brew --prefix node 2>/dev/null)/bin/node" ] && [ -x "$(brew --prefix node 2>/dev/null)/bin/npm" ]; then
            NODE_BIN="$(brew --prefix node)/bin/node"
            NPM_BIN="$(brew --prefix node)/bin/npm"
        elif brew list node &> /dev/null; then
            brew reinstall node
            NODE_BIN="$(brew --prefix node)/bin/node"
            NPM_BIN="$(brew --prefix node)/bin/npm"
        else
            brew install node
            NODE_BIN="$(brew --prefix node)/bin/node"
            NPM_BIN="$(brew --prefix node)/bin/npm"
        fi
    fi
fi

if [ -z "$NODE_BIN" ] || [ -z "$NPM_BIN" ] || [ ! -x "$NODE_BIN" ] || [ ! -x "$NPM_BIN" ]; then
    echo "❌ node not found. Install Node.js or ensure /opt/homebrew/bin is on your PATH."
    exit 1
fi

export PATH="$(dirname "$NODE_BIN"):$PATH"

# Check if uvicorn is installed
if ! command -v uvicorn &> /dev/null; then
    echo "❌ uvicorn not found. Installing..."
    pip install uvicorn fastapi
fi

# Function to free a port by killing all processes using it
free_port() {
    local port=$1
    local pids=$(lsof -ti:"$port" 2>/dev/null)
    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}⚠️  Port $port already in use (PIDs: $pids). Stopping existing processes...${NC}"
        echo "$pids" | xargs kill -9 2>/dev/null
        # Wait until port is actually free (up to 5 seconds)
        for i in $(seq 1 10); do
            if ! lsof -ti:"$port" &>/dev/null; then
                break
            fi
            sleep 0.5
        done
        if lsof -ti:"$port" &>/dev/null; then
            echo "❌ Could not free port $port. Please manually stop the process."
            exit 1
        fi
    fi
}

# Kill any existing processes on required ports
free_port 8000
free_port 5173

# Start FastAPI backend in background
echo -e "${BLUE}🔧 Starting FastAPI backend on port 8000...${NC}"
uvicorn api.main:app --reload --port 8000 > backend.log 2>&1 &
BACKEND_PID=$!

# Give backend a moment to start
sleep 3

# Check if backend is running
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "❌ Backend failed to start. Check backend.log for details."
    exit 1
fi

echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"

# Fetch the configured LLM from the backend
LLM_DISPLAY=$(curl -s http://localhost:8000/llm_info 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('display', 'No LLM active'))" 2>/dev/null || echo "No LLM active")
echo -e "${BLUE}🤖 LLM:${NC} $LLM_DISPLAY"

# Check if npm dependencies are installed
if [ ! -d "vokabel-app/node_modules" ]; then
    echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
    cd vokabel-app
    "$NPM_BIN" install
    cd ..
fi

# Start Vue.js frontend
echo -e "${BLUE}🎨 Starting Vue.js frontend...${NC}"
cd vokabel-app
"$NPM_BIN" run dev > ../frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Give frontend a moment to start
sleep 3

# Check if frontend is running
if ! kill -0 $FRONTEND_PID 2>/dev/null; then
    echo "❌ Frontend failed to start. Check frontend.log for details."
    cleanup
    exit 1
fi

echo -e "${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Application started successfully!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📡 Backend API:${NC}       http://localhost:8000"
echo -e "${BLUE}🌐 Frontend UI:${NC}       http://localhost:5173"
echo -e "${BLUE}📚 API Swagger Docs:${NC}  http://localhost:8000/swagger"
echo -e "${BLUE}🤖 LLM:${NC}               $LLM_DISPLAY"
echo ""
echo -e "${YELLOW}💡 Logs:${NC}"
echo "   Backend:  tail -f backend.log"
echo "   Frontend: tail -f frontend.log"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop both servers...${NC}"
echo ""

# Wait for both processes
wait $BACKEND_PID $FRONTEND_PID
