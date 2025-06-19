#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_title() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║$1${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_user_action() {
    echo -e "${YELLOW}👤 USER ACTION: $1${NC}"
}

print_agent_action() {
    echo -e "${GREEN}🤖 AGENT: $1${NC}"
}

print_system_response() {
    echo -e "${GREEN}📡 SYSTEM: $1${NC}"
}

# Function to wait with countdown
wait_with_demo() {
    local seconds=$1
    local message=$2
    echo -e "${YELLOW}$message${NC}"
    for ((i=seconds; i>0; i--)); do
        echo -ne "\rWaiting ${i}s..."
        sleep 1
    done
    echo -e "\r          \r" # Clear the countdown line
}

# Function to execute dfx command with pretty output
execute_demo_command() {
    local description=$1
    local command=$2
    local explain=$3
    
    print_info "$description"
    echo -e "${CYAN}Command: ${NC}$command"
    
    if [ ! -z "$explain" ]; then
        echo -e "${YELLOW}What this does: ${NC}$explain"
    fi
    
    echo -e "${BLUE}Response:${NC}"
    if eval "$command"; then
        print_success "Command executed successfully"
    else
        print_error "Command failed"
        exit 1
    fi
    echo
}

# Function to check and install dfx
check_and_install_dfx() {
    print_step "Pre-flight Check: DFX Installation"
    
    if command -v dfx &> /dev/null; then
        local dfx_version=$(dfx --version 2>/dev/null | head -n1)
        print_success "DFX is available: $dfx_version"
        return 0
    fi
    
    print_info "DFX not found. Please install DFX first:"
    echo "curl -fsSL https://sdk.dfinity.org/install.sh | sh"
    exit 1
}

# Function to check if we're in the right directory
check_project_structure() {
    print_step "Project Structure Check"
    
    if [ ! -f "dfx.json" ]; then
        print_error "dfx.json not found. Please run this script from your ResearchOS project root."
        print_info "Expected structure:"
        echo "  research_ai_simple/"
        echo "  ├── dfx.json"
        echo "  ├── src/"
        echo "  │   └── backend/"
        echo "  │       └── public/"
        echo "  │           └── index.html"
        echo "  └── demo_user_journey.sh"
        exit 1
    fi
    
    # Find the actual backend directory (it might be named differently)
    BACKEND_DIR=$(find src/ -name "*backend*" -type d | head -1)
    if [ -z "$BACKEND_DIR" ]; then
        print_error "No backend directory found in src/"
        exit 1
    fi
    
    print_success "Project structure looks good - found backend at: $BACKEND_DIR"
    
    # Get the actual canister name from dfx.json
    CANISTER_NAME=$(grep -o '"[^"]*backend[^"]*"' dfx.json | head -1 | tr -d '"' | sed 's/_backend.*/_backend/')
    if [ -z "$CANISTER_NAME" ]; then
        CANISTER_NAME="research_ai_simple_backend"
    fi
    print_info "Using canister name: $CANISTER_NAME"
}

# Function to start local replica
start_local_replica() {
    print_step "Starting Local ICP Replica"
    print_info "Checking if local replica is already running..."
    
    if dfx ping local &> /dev/null; then
        print_success "Local replica is already running"
        return 0
    fi
    
    print_info "Starting fresh local replica..."
    dfx start --clean --background
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if dfx ping local &> /dev/null; then
            print_success "Local replica started successfully"
            return 0
        fi
        
        echo -ne "\rWaiting for replica to start... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    echo
    print_error "Failed to start local replica after $max_attempts attempts"
    exit 1
}

# Function to compile and deploy canister
compile_and_deploy() {
    print_step "Compiling and Deploying ResearchOS News Network"
    
    print_info "Adding WASM target..."
    rustup target add wasm32-unknown-unknown
    
    print_info "Compiling Rust canister code..."
    if ! cargo build --target wasm32-unknown-unknown --release; then
        print_error "Compilation failed. Please check your Rust code."
        exit 1
    fi
    print_success "Compilation successful"
    
    print_info "Deploying canister to local replica..."
    if ! dfx deploy $CANISTER_NAME; then
        print_error "Deployment failed. Check dfx.json configuration."
        exit 1
    fi
    print_success "Canister deployed successfully"
    
    # Get and display canister ID
    CANISTER_ID=$(dfx canister id $CANISTER_NAME 2>/dev/null)
    if [ ! -z "$CANISTER_ID" ]; then
        print_success "Canister ID: $CANISTER_ID"
    fi
}

# Function to launch Express.js UI
launch_ui() {
    print_step "Launching ResearchOS Express.js UI"
    
    # Check if the Express app directory exists
    EXPRESS_DIR="src/backend"
    if [ ! -d "$EXPRESS_DIR" ]; then
        print_error "Express backend directory not found: $EXPRESS_DIR"
        return 1
    fi
    
    # Check if index.html exists
    UI_FILE="$EXPRESS_DIR/public/index.html"
    if [ ! -f "$UI_FILE" ]; then
        print_error "UI file not found: $UI_FILE"
        print_info "Please ensure index.html is in src/backend/public/"
        return 1
    fi
    
    # Change to Express directory
    cd "$EXPRESS_DIR"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_error "package.json not found in $EXPRESS_DIR"
        cd - > /dev/null
        return 1
    fi
    
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ]; then
        print_info "Installing Express.js dependencies..."
        if command -v npm &> /dev/null; then
            npm install
        else
            print_error "npm not found. Please install Node.js and npm"
            cd - > /dev/null
            return 1
        fi
    fi
    
    # Export canister ID as environment variable
    export CANISTER_ID="$CANISTER_ID"
    export CANISTER_NETWORK="local"
    
    print_info "Starting Express.js server with Canister ID: $CANISTER_ID"
    
    # Create a temporary script that modifies the HTML with canister ID
    cat > inject-canister.js << EOF
const fs = require('fs');
const path = require('path');

// Read the original HTML
const htmlPath = path.join(__dirname, 'public', 'index.html');
const originalHtml = fs.readFileSync(htmlPath, 'utf8');

// Inject canister ID configuration
const injectionScript = \`
<script>
    // Auto-configure canister ID from deployment
    window.DEPLOYED_CANISTER_ID = '$CANISTER_ID';
    window.CANISTER_NETWORK = 'local';
    
    window.addEventListener('DOMContentLoaded', () => {
        const canisterInput = document.getElementById('canisterId');
        const networkSelect = document.getElementById('networkSelect');
        
        // If elements exist and are empty, auto-fill them
        if (canisterInput && !canisterInput.value) {
            canisterInput.value = window.DEPLOYED_CANISTER_ID;
            if (networkSelect) {
                networkSelect.value = window.CANISTER_NETWORK;
            }
            // Trigger change event to auto-connect
            canisterInput.dispatchEvent(new Event('change'));
            
            // Add console message
            console.log('Auto-configured with Canister ID:', window.DEPLOYED_CANISTER_ID);
        }
    });
</script>
\`;

// Inject before closing body tag
const modifiedHtml = originalHtml.replace('</body>', injectionScript + '</body>');

// Write to a temporary file
fs.writeFileSync(path.join(__dirname, 'public', 'index-configured.html'), modifiedHtml);

console.log('Canister ID injected into UI');
EOF
    
    # Run the injection script
    node inject-canister.js
    
    # Check if there's a custom start script in package.json
    if grep -q '"start"' package.json; then
        print_info "Starting Express server using npm start..."
        
        # Start the Express server with environment variables
        CANISTER_ID="$CANISTER_ID" npm start &
        SERVER_PID=$!
    else
        # Fallback to node command
        print_info "Starting Express server..."
        
        # Look for common Express entry points
        if [ -f "index.js" ]; then
            CANISTER_ID="$CANISTER_ID" node index.js &
            SERVER_PID=$!
        elif [ -f "app.js" ]; then
            CANISTER_ID="$CANISTER_ID" node app.js &
            SERVER_PID=$!
        elif [ -f "server.js" ]; then
            CANISTER_ID="$CANISTER_ID" node server.js &
            SERVER_PID=$!
        else
            print_error "Could not find Express entry point (index.js, app.js, or server.js)"
            cd - > /dev/null
            return 1
        fi
    fi
    
    # Change back to original directory
    cd - > /dev/null
    
    # Wait for server to start
    sleep 3
    
    # Default Express port
    PORT=${EXPRESS_PORT:-3000}
    UI_URL="http://localhost:$PORT"
    
    print_success "Express server started with PID: $SERVER_PID"
    print_info "UI available at: $UI_URL"
    print_success "Canister ID automatically configured: $CANISTER_ID"
    
    # Try to open in default browser
    if command -v open &> /dev/null; then
        # macOS
        open "$UI_URL"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "$UI_URL"
    elif command -v start &> /dev/null; then
        # Windows
        start "$UI_URL"
    else
        print_info "Please open your browser and navigate to:"
        echo -e "${YELLOW}$UI_URL${NC}"
    fi
    
    # Store server PID for cleanup
    echo $SERVER_PID > .ui_server.pid
    
    # Add cleanup instructions
    echo
    print_info "To stop the UI server later, run:"
    echo -e "${YELLOW}kill $SERVER_PID${NC}"
    echo -e "or: ${YELLOW}kill \$(cat .ui_server.pid)${NC}"
}

# Main demo script
print_title "             ResearchOS News Network - User Journey Demo           "

echo -e "${CYAN}This demo shows a real user journey with ResearchOS:${NC}"
echo -e "${CYAN}→ User searches for news about a topic${NC}"
echo -e "${CYAN}→ Groq AI agent fetches and summarizes latest information${NC}"
echo -e "${CYAN}→ Optional: Enable 20-minute auto-updates for the topic${NC}"
echo -e "${CYAN}→ View history and manage tracked topics${NC}"
echo

wait_with_demo 3 "Starting ResearchOS News Network demo in"

# Pre-flight checks
check_and_install_dfx
check_project_structure

# Start local replica
start_local_replica

wait_with_demo 2 "Local replica ready. Now compiling and deploying..."

# Compile and deploy
compile_and_deploy

wait_with_demo 3 "News Network deployed! Starting user journey demo..."

# === USER JOURNEY BEGINS ===

print_title "                     User Journey: Finding News                    "

# Health check
print_step "System Initialization"
execute_demo_command \
    "Checking news network status" \
    "dfx canister call $CANISTER_NAME health_check" \
    "Verifies the canister is running and shows storage status"

wait_with_demo 2 "System ready. Let's simulate a user searching for news..."

# User searches for news WITHOUT tracking
print_step "Journey Step 1: User Searches for Lagos News"
print_user_action "User types 'latest news in Lagos' and clicks 'Tell me the scoop!'"
print_agent_action "News Agent activates..."

execute_demo_command \
    "Searching for Lagos news (no tracking)" \
    "dfx canister call $CANISTER_NAME get_news '(record {
  topic = \"latest news in Lagos\";
  enable_tracking = false
})'" \
    "The Groq AI agent queries for latest Lagos news and returns results"

wait_with_demo 3 "News retrieved! Now user wants to track this topic..."

# User searches again WITH tracking enabled
print_step "Journey Step 2: User Enables Auto-Updates"
print_user_action "User toggles 'AUTO-UPDATE EVERY 20 MIN' and searches again"
print_agent_action "News Agent activates with tracking enabled..."

execute_demo_command \
    "Searching for Lagos news with auto-updates enabled" \
    "dfx canister call $CANISTER_NAME get_news '(record {
  topic = \"latest news in Lagos\";
  enable_tracking = true
})'" \
    "Same search but now the topic will be updated every 20 minutes"

wait_with_demo 2 "Topic is now being tracked! Let's add another topic..."

# User searches for another topic
print_step "Journey Step 3: User Searches for AI News"
print_user_action "User searches for 'AI breakthroughs 2024' with tracking"
print_agent_action "News Agent processes second query..."

execute_demo_command \
    "Searching for AI breakthroughs with tracking" \
    "dfx canister call $CANISTER_NAME get_news '(record {
  topic = \"AI breakthroughs 2024\";
  enable_tracking = true
})'" \
    "Another topic added to the auto-update list"

wait_with_demo 2 "Now tracking 2 topics. Let's see what's being monitored..."

# View tracked topics
print_step "Journey Step 4: User Views Tracked Topics"
print_user_action "User clicks 'View Tracked Topics' button"
print_system_response "Displaying all monitored topics..."

execute_demo_command \
    "Viewing all tracked topics" \
    "dfx canister call $CANISTER_NAME get_tracked_topics" \
    "Shows all topics being monitored with update counts and timestamps"

wait_with_demo 3 "User can see both topics are being tracked..."

# Simulate timer update
print_step "Journey Step 5: Behind the Scenes - Timer Update"
print_agent_action "Timer Agent (runs every 20 min in production)..."
print_info "In production, this happens automatically. Let's trigger it manually:"

execute_demo_command \
    "Manually triggering update cycle (simulating timer)" \
    "dfx canister call $CANISTER_NAME trigger_update_cycle" \
    "All tracked topics get fresh news from Groq AI"

wait_with_demo 3 "All topics updated! Now let's check the history..."

# View history
print_step "Journey Step 6: User Views News History"
print_user_action "User wants to see historical updates for Lagos"
print_system_response "Retrieving news history..."

execute_demo_command \
    "Getting news history for Lagos (last 3 updates)" \
    "dfx canister call $CANISTER_NAME get_news_history '(\"latest news in Lagos\", opt 3)'" \
    "Shows historical news updates for this topic"

wait_with_demo 2 "User can see how news evolved over time..."

# Get latest stored news
print_step "Journey Step 7: Quick Check Latest News"
print_user_action "User wants just the latest stored news without a new search"

execute_demo_command \
    "Getting latest cached news for Lagos" \
    "dfx canister call $CANISTER_NAME get_latest_stored_news '(\"latest news in Lagos\")'" \
    "Returns the most recent stored update without calling Groq AI"

wait_with_demo 2 "Perfect for quick checks without using API calls..."

# Untrack a topic
print_step "Journey Step 8: User Stops Tracking a Topic"
print_user_action "User clicks the × button next to 'AI breakthroughs 2024'"

execute_demo_command \
    "Untracking AI breakthroughs topic" \
    "dfx canister call $CANISTER_NAME untrack_topic '(\"AI breakthroughs 2024\")'" \
    "Removes topic from auto-update list"

# Final status check
print_step "Journey Complete: Final System Status"
execute_demo_command \
    "Final system check" \
    "dfx canister call $CANISTER_NAME health_check" \
    "Shows final state with stored items and tracked topics"

wait_with_demo 3 "Demo completed! Here's what happened behind the scenes..."

# Summary
print_title "                    Agent Coordination Summary                     "

echo -e "${GREEN}✓ ResearchOS News Network User Journey Completed!${NC}"
echo
echo -e "${CYAN}What happened during the user journey:${NC}"
echo -e "  ${GREEN}1.${NC} User searched for news → Groq AI agent fetched latest information"
echo -e "  ${GREEN}2.${NC} User enabled tracking → Topic added to 20-minute update list"
echo -e "  ${GREEN}3.${NC} Timer agent (background) → Automatically updates all tracked topics"
echo -e "  ${GREEN}4.${NC} Storage agent → Maintains history of all news updates"
echo -e "  ${GREEN}5.${NC} User can view history → See how news changes over time"
echo
echo -e "${CYAN}Agent Coordination Behind the Scenes:${NC}"
echo -e "  ${PURPLE}→${NC} News Agent: Interfaces with Groq AI to fetch news"
echo -e "  ${PURPLE}→${NC} Storage Agent: Keeps all news updates with timestamps"
echo -e "  ${PURPLE}→${NC} Timer Agent: Runs every 20 minutes to refresh tracked topics"
echo -e "  ${PURPLE}→${NC} Tracking Agent: Manages which topics to auto-update"
echo
echo -e "${CYAN}Key Features Demonstrated:${NC}"
echo -e "  ${YELLOW}→${NC} Instant news search with AI summarization"
echo -e "  ${YELLOW}→${NC} Optional auto-updates every 20 minutes"
echo -e "  ${YELLOW}→${NC} Historical news tracking"
echo -e "  ${YELLOW}→${NC} Topic management (track/untrack)"
echo -e "  ${YELLOW}→${NC} Cached results for quick access"
echo

# Launch UI
wait_with_demo 3 "Launching ResearchOS News Network UI..."
launch_ui

echo
echo -e "${CYAN}Try it yourself in the UI:${NC}"
echo -e "  ${YELLOW}1.${NC} Search for any topic (e.g., 'crypto market', 'tech startups')"
echo -e "  ${YELLOW}2.${NC} Toggle auto-updates to track topics"
echo -e "  ${YELLOW}3.${NC} Click 'View Tracked Topics' to manage your list"
echo -e "  ${YELLOW}4.${NC} Use 'News History' to see past updates"
echo -e "  ${YELLOW}5.${NC} Force an update with 'Force Update Now'"
echo
echo -e "${PURPLE}Your ResearchOS News Network is live and ready!${NC}"

print_title "                        Demo Complete                              "

echo -e "${BLUE}Advanced commands for power users:${NC}"
echo -e "${BLUE}Get news: ${NC}dfx canister call $CANISTER_NAME get_news '(record { topic = \"your topic\"; enable_tracking = true })'"
echo -e "${BLUE}View tracked: ${NC}dfx canister call $CANISTER_NAME get_tracked_topics"
echo -e "${BLUE}Get history: ${NC}dfx canister call $CANISTER_NAME get_news_history '(\"topic\", opt 5)'"
echo -e "${BLUE}Force update: ${NC}dfx canister call $CANISTER_NAME trigger_update_cycle"
echo
echo -e "${GREEN}ResearchOS UI launched with Canister ID: ${CANISTER_ID}${NC}"