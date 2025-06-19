#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to wait with countdown
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

# Step 9: Final State Check
print_step "Step 9: Final State Verification"
execute_dfx "Final shared memory state - all agent data should be visible" \
    "dfx canister call research_ai_simple_backend get_all_data '()'"

wait_with_countdown 3 "Test sequence complete! Cleaning up..."

# Step 10: Cleanup (Optional)
print_step "Step 10: Cleanup"
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
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_info "Next steps:"
echo "  1. Add HTTP querying agents"
echo "  2. Implement tag generation"
echo "  3. Add search functionality"
echo "  4. Build agent decision-making logic"