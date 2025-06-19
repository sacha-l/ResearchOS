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

print_system_response() {
    echo -e "${GREEN}🤖 SYSTEM RESPONSE: $1${NC}"
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
        echo "  researchos/"
        echo "  ├── dfx.json"
        echo "  ├── src/"
        echo "  │   └── research_ai_simple_backend/"
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
    print_step "Compiling and Deploying ResearchOS Agent Network"
    
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
    local canister_id=$(dfx canister id $CANISTER_NAME 2>/dev/null)
    if [ ! -z "$canister_id" ]; then
        print_success "Canister ID: $canister_id"
    fi
}

# Main demo script
print_title "                ResearchOS Agent Network Demo                      "

echo -e "${CYAN}This demo shows the ResearchOS multi-agent coordination system:${NC}"
echo -e "${CYAN}0. Deploy multi-agent canister to local ICP${NC}"
echo -e "${CYAN}1. Agent 1: Store and retrieve data${NC}"
echo -e "${CYAN}2. Agent 2: Fetch data from external APIs${NC}"
echo -e "${CYAN}3. Agent 3: Query Groq AI for research${NC}"
echo -e "${CYAN}4. Demonstrate agent coordination and shared memory${NC}"
echo

wait_with_demo 3 "Starting agent network demo in"

# Pre-flight checks
check_and_install_dfx
check_project_structure

# Start local replica
start_local_replica

wait_with_demo 2 "Local replica ready. Now compiling and deploying..."

# Compile and deploy
compile_and_deploy

wait_with_demo 3 "Agent network deployed! Starting coordination demo..."

print_step "Step 1: System Health Check"
print_user_action "User wants to verify the agent network is running"
execute_demo_command \
    "Checking agent network health" \
    "dfx canister call $CANISTER_NAME health_check" \
    "Shows how many items are stored in the shared agent memory"

wait_with_demo 2 "Now demonstrating Agent 1: Storage operations..."

# Agent 1: Storage operations
print_step "Step 2: Agent 1 - Data Storage Operations"
print_user_action "Agent 1 stores research data in shared memory"
execute_demo_command \
    "Agent 1 stores AI research data" \
    "dfx canister call $CANISTER_NAME agent_store_data '(record {
  key = \"ai_research_status\";
  value = \"Currently researching: neural networks, quantum computing, and blockchain scalability\";
  agent_id = \"storage_agent_001\"
})'" \
    "Agent 1 stores key research topics in shared memory for other agents to access"

execute_demo_command \
    "Agent 1 stores another data point" \
    "dfx canister call $CANISTER_NAME agent_store_data '(record {
  key = \"research_priority\";
  value = \"High priority: AI safety and alignment research\";
  agent_id = \"storage_agent_001\"
})'" \
    "Agent 1 adds priority information to shared knowledge base"

wait_with_demo 2 "Now testing data retrieval..."

execute_demo_command \
    "Retrieving stored research status" \
    "dfx canister call $CANISTER_NAME agent_get_data '(\"ai_research_status\")'" \
    "Any agent can retrieve data stored by other agents"

wait_with_demo 3 "Now demonstrating Agent 2: HTTP API queries..."

# Agent 2: HTTP operations
print_step "Step 3: Agent 2 - External API Integration"
print_user_action "Agent 2 fetches live data from external APIs"
execute_demo_command \
    "Agent 2 fetches current time from world clock API" \
    "dfx canister call $CANISTER_NAME agent_query_http '(record {
  url = \"http://worldtimeapi.org/api/timezone/UTC\";
  agent_id = \"http_agent_002\";
  store_key = \"current_utc_time\"
})'" \
    "Agent 2 uses ICP HTTP outcalls to fetch real-time data and store it for the network"

wait_with_demo 2 "Checking what Agent 2 fetched..."

execute_demo_command \
    "Retrieving the fetched time data" \
    "dfx canister call $CANISTER_NAME agent_get_data '(\"current_utc_time\")'" \
    "Shows the live UTC time data fetched by Agent 2"

wait_with_demo 3 "Now the exciting part - Agent 3: Groq AI integration..."

# Agent 3: Groq AI operations
print_step "Step 4: Agent 3 - Groq AI Research Queries"
print_user_action "Agent 3 queries Groq AI for research insights"
execute_demo_command \
    "Agent 3 asks Groq AI about quantum computing" \
    "dfx canister call $CANISTER_NAME agent_query_groq '(record {
  prompt = \"What are the latest breakthroughs in quantum computing in 2024?\";
  agent_id = \"groq_research_agent_003\";
  store_key = \"quantum_research_2024\"
})'" \
    "Agent 3 uses ICP HTTP outcalls to query Groq AI directly from the blockchain"

wait_with_demo 4 "Agent 3 is querying Groq AI... this may take a moment..."

execute_demo_command \
    "Retrieving Groq AI research response" \
    "dfx canister call $CANISTER_NAME agent_get_data '(\"quantum_research_2024\")'" \
    "Shows the AI-generated research insights about quantum computing"

wait_with_demo 2 "Let's have Agent 3 research another topic..."

execute_demo_command \
    "Agent 3 asks Groq AI about blockchain scalability" \
    "dfx canister call $CANISTER_NAME agent_query_groq '(record {
  prompt = \"Explain the current state of blockchain scalability solutions\";
  agent_id = \"groq_research_agent_003\";
  store_key = \"blockchain_scalability\"
})'" \
    "Agent 3 expands the research knowledge base with blockchain insights"

wait_with_demo 3 "Processing AI response..."

execute_demo_command \
    "Retrieving blockchain scalability research" \
    "dfx canister call $CANISTER_NAME agent_get_data '(\"blockchain_scalability\")'" \
    "Shows AI-generated insights about blockchain scalability"

wait_with_demo 2 "Now let's see all the data our agent network has collected..."

# View all collected data
print_step "Step 5: Agent Network Coordination - Shared Knowledge"
print_user_action "User wants to see all data collected by the agent network"
execute_demo_command \
    "Viewing complete shared knowledge base" \
    "dfx canister call $CANISTER_NAME get_all_data" \
    "Shows all data stored by Agent 1, fetched by Agent 2, and researched by Agent 3"

wait_with_demo 2 "Final system health check..."

# Final health check
print_step "Step 6: Final Agent Network Status"
print_user_action "User checks the final state of the agent network"
execute_demo_command \
    "Final health check showing network growth" \
    "dfx canister call $CANISTER_NAME health_check" \
    "Shows how the shared memory has grown through agent coordination"

wait_with_demo 3 "Demo completed! Here's what our agents accomplished..."

# Summary
print_title "                         Agent Network Summary                      "

echo -e "${GREEN}✓ ResearchOS Agent Network Demo Completed Successfully!${NC}"
echo
echo -e "${CYAN}What our agents accomplished:${NC}"
echo -e "  ${GREEN}→${NC} Agent 1 (Storage): Stored research priorities and status data"
echo -e "  ${GREEN}→${NC} Agent 2 (HTTP): Fetched live UTC time data from external API"
echo -e "  ${GREEN}→${NC} Agent 3 (Groq AI): Generated research insights on quantum computing and blockchain"
echo -e "  ${GREEN}→${NC} All agents shared data through common memory space"
echo
echo -e "${CYAN}ICP Blockchain Features Demonstrated:${NC}"
echo -e "  ${GREEN}→${NC} HTTP Outcalls: Direct API access without oracles"
echo -e "  ${GREEN}→${NC} Persistent Storage: Data survives between function calls"
echo -e "  ${GREEN}→${NC} Multi-Agent Coordination: Agents share knowledge seamlessly"
echo -e "  ${GREEN}→${NC} AI Integration: Direct Groq AI queries from blockchain"
echo
echo -e "${CYAN}Real-World Applications:${NC}"
echo -e "  ${GREEN}→${NC} Autonomous research networks"
echo -e "  ${GREEN}→${NC} Multi-source data aggregation"
echo -e "  ${GREEN}→${NC} AI-powered blockchain applications"
echo -e "  ${GREEN}→${NC} Decentralized knowledge management"
echo
echo -e "${CYAN}Next Steps:${NC}"
echo -e "  ${YELLOW}→${NC} Deploy to mainnet: dfx deploy --network ic"
echo -e "  ${YELLOW}→${NC} Add more specialized agents"
echo -e "  ${YELLOW}→${NC} Implement timer-based autonomous operations"
echo -e "  ${YELLOW}→${NC} Build frontend interface for agent coordination"
echo
echo -e "${PURPLE}Your agent network is now operational and ready for research!${NC}"

print_title "                        Demo Complete                              "

echo -e "${BLUE}To interact with your agents:${NC}"
echo -e "${BLUE}Store data: ${NC}dfx canister call $CANISTER_NAME agent_store_data '(record { key = \"test\"; value = \"data\"; agent_id = \"agent1\" })'"
echo -e "${BLUE}Fetch HTTP: ${NC}dfx canister call $CANISTER_NAME agent_query_http '(record { url = \"http://example.com\"; agent_id = \"agent2\"; store_key = \"result\" })'"
echo -e "${BLUE}Query Groq: ${NC}dfx canister call $CANISTER_NAME agent_query_groq '(record { prompt = \"your question\"; agent_id = \"agent3\"; store_key = \"ai_result\" })'"
echo -e "${BLUE}Get data: ${NC}dfx canister call $CANISTER_NAME agent_get_data '(\"key_name\")'"
echo -e "${BLUE}View all: ${NC}dfx canister call $CANISTER_NAME get_all_data"