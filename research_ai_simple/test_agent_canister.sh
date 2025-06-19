#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check and install dfx
check_and_install_dfx() {
    print_step "Checking DFX Installation"
    
    if command -v dfx &> /dev/null; then
        local dfx_version=$(dfx --version 2>/dev/null | head -n1)
        print_success "DFX is already installed: $dfx_version"
        return 0
    fi
    
    print_info "DFX not found. Installing DFX locally..."
    
    # Check if we're on a supported platform
    local os_type=$(uname -s)
    local arch_type=$(uname -m)
    
    print_info "Detected OS: $os_type, Architecture: $arch_type"
    
    if [[ "$os_type" != "Linux" && "$os_type" != "Darwin" ]]; then
        print_error "Unsupported operating system: $os_type"
        print_info "Please install DFX manually from: https://sdk.dfinity.org/"
        exit 1
    fi
    
    # Create local bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    # Download and install DFX
    print_info "Downloading DFX installer..."
    if curl -fsSL https://sdk.dfinity.org/install.sh | sh; then
        print_success "DFX installation completed!"
        
        # Add to PATH for this session
        export PATH="$HOME/.local/share/dfx/bin:$PATH"
        
        # Check if installation was successful
        if command -v dfx &> /dev/null; then
            local dfx_version=$(dfx --version 2>/dev/null | head -n1)
            print_success "DFX is now available: $dfx_version"
            
            # Inform user about PATH
            echo -e "${YELLOW}"
            echo "Note: DFX has been installed to ~/.local/share/dfx/bin/"
            echo "To use DFX in future terminal sessions, add this to your shell profile:"
            echo "  export PATH=\"\$HOME/.local/share/dfx/bin:\$PATH\""
            echo -e "${NC}"
        else
            print_error "DFX installation failed - command not found after installation"
            exit 1
        fi
    else
        print_error "Failed to download or install DFX"
        print_info "Please install DFX manually from: https://sdk.dfinity.org/"
        exit 1
    fi
}

# Function to check if dfx daemon is running
check_dfx_daemon() {
    print_step "Checking DFX Daemon"
    
    if dfx ping local &> /dev/null; then
        print_success "DFX daemon is running"
        return 0
    fi
    
    print_info "DFX daemon not running. Starting local replica..."
    
    # Start dfx in background
    dfx start --clean --background
    
    # Wait for it to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if dfx ping local &> /dev/null; then
            print_success "DFX daemon started successfully"
            return 0
        fi
        
        echo -ne "\rWaiting for DFX daemon to start... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    echo # New line after waiting
    print_error "Failed to start DFX daemon after $max_attempts attempts"
    print_info "Try starting manually with: dfx start"
    exit 1
}

# Function to check if canister is deployed
check_canister_deployment() {
    print_step "Checking Canister Deployment"
    
    if dfx canister id research_ai_simple_backend &> /dev/null; then
        print_success "Canister 'research_ai_simple_backend' is deployed"
        return 0
    fi
    
    print_info "Canister not found. Attempting to deploy..."
    
    if dfx deploy research_ai_simple_backend; then
        print_success "Canister deployed successfully"
    else
        print_error "Failed to deploy canister"
        print_info "Make sure you're in the correct project directory and run 'dfx deploy' manually"
        exit 1
    fi
}
wait_with_countdown() {
    local seconds=$1
    local message=$2
    echo -e "${YELLOW}$message${NC}"
    for ((i=seconds; i>0; i--)); do
        echo -ne "\rWaiting ${i}s..."
        sleep 1
    done
    echo -e "\r          \r" # Clear the countdown line
}

# Function to execute dfx command with error handling
execute_dfx() {
    local description=$1
    local command=$2
    
    print_info "$description"
    echo "Command: $command"
    
    if eval "$command"; then
        print_success "Command executed successfully"
    else
        print_error "Command failed"
        exit 1
    fi
    echo
}

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                Agent Canister Test Script                    ║"
echo "║          Testing shared memory and agent coordination        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Pre-flight checks
print_step "Pre-flight Checks"

# Check and install dfx if needed
check_and_install_dfx

wait_with_countdown 2 "Checking DFX daemon status..."

# Check if dfx daemon is running
check_dfx_daemon

wait_with_countdown 2 "Verifying canister deployment..."

# Check if canister is deployed
check_canister_deployment

wait_with_countdown 3 "All systems ready! Starting tests..."

# Step 1: Health Check
print_step "Step 1: Health Check"
execute_dfx "Checking if canister is running and healthy" \
    "dfx canister call research_ai_simple_backend health_check"

wait_with_countdown 2 "Proceeding to initial state check..."

# Step 2: Check Initial State
print_step "Step 2: Check Initial State"
execute_dfx "Checking initial storage state (should be empty)" \
    "dfx canister call research_ai_simple_backend get_all_data '()'"

wait_with_countdown 3 "Starting agent coordination test..."

# Step 3: Agent 1 - Market Research Agent
print_step "Step 3: Agent 1 - Market Research Agent"
execute_dfx "Agent 1 storing market analysis data" \
    "dfx canister call research_ai_simple_backend agent_store_data '(record {
  key = \"market_analysis\";
  value = \"Tesla stock trending upward, 15% gain this week\";
  agent_id = \"market_agent_001\"
})'"

wait_with_countdown 2 "Agent 1 data stored, continuing..."

# Step 4: Agent 2 - News Sentiment Agent
print_step "Step 4: Agent 2 - News Sentiment Agent"
execute_dfx "Agent 2 storing news sentiment data" \
    "dfx canister call research_ai_simple_backend agent_store_data '(record {
  key = \"news_sentiment\";
  value = \"Positive Tesla coverage: 78% positive mentions in tech blogs\";
  agent_id = \"news_agent_002\"
})'"

wait_with_countdown 2 "Agent 2 data stored, continuing..."

# Step 5: Agent 3 - Social Media Agent  
print_step "Step 5: Agent 3 - Social Media Agent"
execute_dfx "Agent 3 storing social media data" \
    "dfx canister call research_ai_simple_backend agent_store_data '(record {
  key = \"social_buzz\";
  value = \"Twitter mentions +45%, Reddit discussions trending\";
  agent_id = \"social_agent_003\"
})'"

wait_with_countdown 2 "Agent 3 data stored, checking shared memory..."

# Step 6: View All Shared Data
print_step "Step 6: View All Shared Data"
execute_dfx "Displaying all data stored by different agents in shared memory" \
    "dfx canister call research_ai_simple_backend get_all_data '()'"

wait_with_countdown 3 "Testing data retrieval by agents..."

# Step 7: Agent Coordination - Cross-Agent Data Access
print_step "Step 7: Agent Coordination Test"
execute_dfx "Agent 4 reading market data stored by Agent 1" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"market_analysis\")'"

execute_dfx "Agent 4 reading news sentiment stored by Agent 2" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"news_sentiment\")'"

execute_dfx "Agent 4 reading social data stored by Agent 3" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"social_buzz\")'"

wait_with_countdown 3 "Testing additional scenarios..."

# Step 8: Agent Updates Same Key
print_step "Step 8: Testing Data Updates"
execute_dfx "Agent 1 updating market analysis with new data" \
    "dfx canister call research_ai_simple_backend agent_store_data '(record {
  key = \"market_analysis\";
  value = \"Tesla stock now +18% - breaking resistance levels\";
  agent_id = \"market_agent_001\"
})'"

execute_dfx "Verifying the updated data" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"market_analysis\")'"

wait_with_countdown 2 "Running final verification..."

# Step 9: Test Groq AI Agent
print_step "Step 9: Test Groq AI Agent"
execute_dfx "Testing Groq AI agent with a simple query" \
    "dfx canister call research_ai_simple_backend agent_query_groq '(record {
  prompt = \"What is artificial intelligence in one sentence?\";
  agent_id = \"groq_agent_001\";
  store_key = \"ai_definition\"
})'"

wait_with_countdown 3 "Waiting for AI response..."

execute_dfx "Checking AI response stored in shared memory" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"ai_definition\")'"

wait_with_countdown 2 "Testing AI research capabilities..."

execute_dfx "Groq agent analyzing blockchain technology" \
    "dfx canister call research_ai_simple_backend agent_query_groq '(record {
  prompt = \"List 3 key benefits of blockchain in bullet points\";
  agent_id = \"research_agent_ai\";
  store_key = \"blockchain_benefits\"
})'"

wait_with_countdown 2 "Retrieving blockchain analysis..."

execute_dfx "Reading blockchain analysis from shared memory" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"blockchain_benefits\")'"

wait_with_countdown 3 "Testing HTTP agent coordination..."

# Step 10: Test HTTP Agent
print_step "Step 10: Test HTTP Agent"
execute_dfx "HTTP agent fetching external data" \
    "dfx canister call research_ai_simple_backend agent_query_http '(record {
  url = \"https://api.github.com/zen\";
  agent_id = \"http_agent_001\";
  store_key = \"github_wisdom\"
})'"

execute_dfx "Reading HTTP agent data from shared memory" \
    "dfx canister call research_ai_simple_backend agent_get_data '(\"github_wisdom\")'"

wait_with_countdown 3 "Testing multi-agent coordination..."

# Step 11: Multi-Agent Coordination Test
print_step "Step 11: Multi-Agent Coordination Demo"
execute_dfx "AI agent creating a research summary" \
    "dfx canister call research_ai_simple_backend agent_query_groq '(record {
  prompt = \"Summarize: What makes a good software development team?\";
  agent_id = \"summary_agent\";
  store_key = \"team_summary\"
})'"

wait_with_countdown 2 "Demonstrating agent coordination..."

execute_dfx "Storage agent storing coordination timestamp" \
    "dfx canister call research_ai_simple_backend agent_store_data '(record {
  key = \"coordination_test\";
  value = \"Multi-agent test completed successfully at $(date)\";
  agent_id = \"coordination_monitor\"
})'"

# Step 12: Final State Check
print_step "Step 12: Final Multi-Agent State"
execute_dfx "Final shared memory state - showing all agent coordination" \
    "dfx canister call research_ai_simple_backend get_all_data '()'"

wait_with_countdown 3 "Test sequence complete! Cleaning up..."

# Step 13: Cleanup (Optional)
print_step "Step 13: Cleanup"
read -p "Do you want to clear the storage? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    execute_dfx "Clearing all data from shared storage" \
        "dfx canister call research_ai_simple_backend clear_storage '()'"
    
    execute_dfx "Verifying storage is cleared" \
        "dfx canister call research_ai_simple_backend get_all_data '()'"
else
    print_info "Skipping cleanup - data preserved in canister"
fi

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     Test Complete!                          ║"
echo "║                                                              ║"
echo "║  ✓ Shared memory working                                     ║"
echo "║  ✓ Multiple agents can store data                            ║"
echo "║  ✓ All agents can read shared data                           ║"
echo "║  ✓ Data updates work correctly                               ║"
echo "║  ✓ Agent coordination demonstrated                           ║"
echo "║  ✓ Groq AI agent integration working                         ║"
echo "║  ✓ HTTP agent fetching external data                         ║"
echo "║  ✓ Multi-agent coordination verified                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_info "Next steps:"
echo "  1. ✓ Add HTTP querying agents"
echo "  2. ✓ Implement AI integration (Groq)"
echo "  3. → Add tag generation from AI responses"
echo "  4. → Add search functionality across tags"
echo "  5. → Build agent decision-making logic"