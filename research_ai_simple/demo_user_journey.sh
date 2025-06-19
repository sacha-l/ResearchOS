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
    
    if [ ! -d "src/research_ai_simple_backend" ]; then
        print_error "Canister source directory not found at src/research_ai_simple_backend"
        exit 1
    fi
    
    print_success "Project structure looks good"
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
    print_step "Compiling and Deploying ResearchOS"
    
    print_info "Compiling Rust canister code..."
    if ! cargo build --target wasm32-unknown-unknown --release --package research_ai_simple_backend; then
        print_error "Compilation failed. Please check your Rust code."
        exit 1
    fi
    print_success "Compilation successful"
    
    print_info "Deploying canister to local replica..."
    if ! dfx deploy research_ai_simple_backend; then
        print_error "Deployment failed. Check dfx.json configuration."
        exit 1
    fi
    print_success "Canister deployed successfully"
    
    # Get and display canister ID
    local canister_id=$(dfx canister id research_ai_simple_backend 2>/dev/null)
    if [ ! -z "$canister_id" ]; then
        print_success "Canister ID: $canister_id"
    fi
}

# Main demo script
print_title "                    ResearchOS User Journey Demo                    "

echo -e "${CYAN}This demo shows the complete ResearchOS development and user journey:${NC}"
echo -e "${CYAN}0. Check environment and compile canister${NC}"
echo -e "${CYAN}1. Deploy ResearchOS to local ICP replica${NC}"
echo -e "${CYAN}2. User asks for news about trending topics${NC}"
echo -e "${CYAN}3. System fetches latest info and starts monitoring${NC}"
echo -e "${CYAN}4. User explores system capabilities${NC}"
echo -e "${CYAN}5. Demonstrate autonomous agent coordination${NC}"
echo

wait_with_demo 3 "Starting complete demo in"

# Pre-flight checks
check_and_install_dfx
check_project_structure

# Start local replica
start_local_replica

wait_with_demo 2 "Local replica ready. Now compiling and deploying..."

# Compile and deploy
compile_and_deploy

wait_with_demo 3 "Deployment complete! Starting user journey..."

print_step "Step 1: System Health Check"
print_user_action "User wants to verify ResearchOS is running"
execute_demo_command \
    "Checking if ResearchOS canister is healthy" \
    "dfx canister call research_ai_simple_backend health_check" \
    "This shows how many topics are cached and monitored"

wait_with_demo 2 "Now user makes their first research request..."

# First news request
print_step "Step 2: First News Request - AI & Technology"
print_user_action "User asks: 'What's the latest news about artificial intelligence?'"
execute_demo_command \
    "User requests latest AI news" \
    "dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = \"artificial intelligence\"
})'" \
    "System fetches fresh news from Groq AI and adds topic to monitoring list"

wait_with_demo 3 "User is impressed! Now they ask about another trending topic..."

# Second news request
print_step "Step 3: Second News Request - Cryptocurrency"
print_user_action "User asks: 'What about the latest cryptocurrency developments?'"
execute_demo_command \
    "User requests crypto news" \
    "dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = \"cryptocurrency market\"
})'" \
    "System fetches fresh crypto news and starts monitoring this topic too"

wait_with_demo 2 "User wants to see what topics are being monitored..."

# Check monitored topics
print_step "Step 4: User Explores - What's Being Monitored?"
print_user_action "User asks: 'What topics is the system monitoring for me?'"
execute_demo_command \
    "Viewing all monitored topics" \
    "dfx canister call research_ai_simple_backend get_monitored_topics" \
    "Shows topics that will be auto-updated every 20 minutes"

wait_with_demo 2 "User wants to see their cached news..."

# View cached news
print_step "Step 5: User Explores - All Cached News"
print_user_action "User asks: 'Show me all the news data you have cached'"
execute_demo_command \
    "Viewing all cached news with timestamps" \
    "dfx canister call research_ai_simple_backend get_all_cached_news" \
    "Shows all news data with last update times and update counts"

wait_with_demo 2 "User requests the same AI topic again to see caching in action..."

# Test caching behavior
print_step "Step 6: Smart Caching Demo"
print_user_action "User asks again: 'What's the latest about artificial intelligence?'"
execute_demo_command \
    "Same AI topic request (should use cache)" \
    "dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = \"artificial intelligence\"
})'" \
    "Since it's less than 20 minutes old, returns cached data instantly (is_fresh: false)"

wait_with_demo 3 "User wants to see what the agents have been doing..."

# Check agent logs
print_step "Step 7: Agent Activity Investigation"
print_user_action "User asks: 'What have the AI agents been doing behind the scenes?'"
execute_demo_command \
    "Viewing recent agent activity logs" \
    "dfx canister call research_ai_simple_backend get_recent_logs" \
    "Shows detailed logs of both user-triggered and autonomous agent activities"

wait_with_demo 2 "User tries a new topic to see the system grow..."

# Add another topic
print_step "Step 8: Adding Another Topic - Space Technology"
print_user_action "User asks: 'What's happening with SpaceX and space technology?'"
execute_demo_command \
    "User requests space technology news" \
    "dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = \"SpaceX space technology\"
})'" \
    "System expands its monitoring to include space technology news"

wait_with_demo 2 "User checks the final system state..."

# Final system state
print_step "Step 9: Final System State"
print_user_action "User asks: 'What's the overall status of my research system?'"
execute_demo_command \
    "Final health check showing growth" \
    "dfx canister call research_ai_simple_backend health_check" \
    "Shows the system now monitors multiple topics and has cached research"

print_info "Checking final monitored topics list:"
execute_demo_command \
    "Final monitored topics" \
    "dfx canister call research_ai_simple_backend get_monitored_topics" \
    "System now monitors 3 topics autonomously"

wait_with_demo 3 "Demo completed! Here's what happened..."

# Summary
print_title "                           Demo Summary                             "

echo -e "${GREEN}✓ Complete ResearchOS Demo Completed Successfully!${NC}"
echo
echo -e "${CYAN}What we accomplished:${NC}"
echo -e "  ${GREEN}→${NC} Verified development environment (DFX, Rust, project structure)"
echo -e "  ${GREEN}→${NC} Started local ICP replica"
echo -e "  ${GREEN}→${NC} Compiled Rust canister code"
echo -e "  ${GREEN}→${NC} Deployed ResearchOS to local blockchain"
echo -e "  ${GREEN}→${NC} Demonstrated complete user journey"
echo -e "  ${GREEN}→${NC} Showed autonomous agent coordination"
echo
echo -e "${CYAN}User journey highlights:${NC}"
echo -e "  ${GREEN}→${NC} Asked for news on 3 different topics"
echo -e "  ${GREEN}→${NC} Got instant fresh news from Groq AI"
echo -e "  ${GREEN}→${NC} Experienced smart caching (no delay on repeat requests)"
echo -e "  ${GREEN}→${NC} Saw transparent agent activity logs"
echo -e "  ${GREEN}→${NC} System automatically started monitoring all requested topics"
echo
echo -e "${CYAN}ICP features demonstrated:${NC}"
echo -e "  ${GREEN}→${NC} HTTP Outcalls: Direct API calls to Groq without oracles"
echo -e "  ${GREEN}→${NC} Timers: Autonomous 20-minute monitoring cycle"
echo -e "  ${GREEN}→${NC} Persistent Storage: Knowledge survives between calls"
echo -e "  ${GREEN}→${NC} Single Canister: All coordination happens on-chain"
echo
echo -e "${CYAN}Next Steps:${NC}"
echo -e "  ${YELLOW}→${NC} Wait 20 minutes and check logs to see autonomous updates"
echo -e "  ${YELLOW}→${NC} Deploy to mainnet: dfx deploy --network ic"
echo -e "  ${YELLOW}→${NC} Add more topics to expand the monitoring network"
echo -e "  ${YELLOW}→${NC} Build frontend interface for better UX"
echo
echo -e "${PURPLE}ResearchOS is now running autonomously, keeping research current!${NC}"

print_title "                        Demo Complete                              "

echo -e "${BLUE}Development cycle complete! To run again: ${NC}./demo_user_journey.sh"
echo -e "${BLUE}Add new topics: ${NC}dfx canister call research_ai_simple_backend get_latest_news '(record { topic = \"your topic\" })'"
echo -e "${BLUE}Deploy to mainnet: ${NC}dfx deploy --network ic research_ai_simple_backend"
echo -e "${BLUE}Check autonomous updates: ${NC}dfx canister call research_ai_simple_backend get_recent_logs"