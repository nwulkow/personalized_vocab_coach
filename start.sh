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

# Check if uvicorn is installed
if ! command -v uvicorn &> /dev/null; then
    echo "❌ uvicorn not found. Installing..."
    pip install uvicorn fastapi
fi

# Kill any existing process on port 8000
EXISTING_PID=$(lsof -ti:8000)
if [ ! -z "$EXISTING_PID" ]; then
    echo -e "${YELLOW}⚠️  Port 8000 already in use (PID: $EXISTING_PID). Stopping existing process...${NC}"
    kill -9 $EXISTING_PID 2>/dev/null
    sleep 1
fi

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

# Check if npm dependencies are installed
if [ ! -d "vokabel-app/node_modules" ]; then
    echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
    cd vokabel-app
    npm install
    cd ..
fi

# Start Vue.js frontend
echo -e "${BLUE}🎨 Starting Vue.js frontend...${NC}"
cd vokabel-app
npm run dev > ../frontend.log 2>&1 &
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
echo ""
echo -e "${YELLOW}💡 Logs:${NC}"
echo "   Backend:  tail -f backend.log"
echo "   Frontend: tail -f frontend.log"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop both servers...${NC}"
echo ""

# Wait for both processes
wait $BACKEND_PID $FRONTEND_PID
